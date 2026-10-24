class_name HalvesMask
extends RefCounted
## Turns a hand-made ASCII stack mask into tile positions and checks it is a fair Halves board.
## Used by the level generator (tools/levelgen/) and the level tests; masks live in
## tools/levelgen/halves_masks.json. One character = one half-unit, so "X.X." is two touching tiles.

const MAX_WIDTH: int = 13
const MAX_HEIGHT: int = 16
const MAX_LAYERS: int = 5


## `layers[z]` is an Array of row strings; returns positions sorted by (z, y, x).
static func parse(layers: Array) -> Array[Vector3i]:
	var positions: Array[Vector3i] = []
	for z in layers.size():
		var rows: Array = layers[z]
		for y in rows.size():
			var row := str(rows[y])
			for x in row.length():
				if row[x] == "X":
					positions.append(Vector3i(x, y, z))
	return positions


## Readable problems with a mask; empty when it is valid (docs/HALVES.md section 2).
static func validate(positions: Array[Vector3i]) -> PackedStringArray:
	var errors := PackedStringArray()
	var count := positions.size()
	if count % 2 != 0:
		errors.append("odd tile count (%d): every tile needs a partner" % count)
	if count > HalvesGeometry.MAX_TILES:
		errors.append("%d tiles, more than %d" % [count, HalvesGeometry.MAX_TILES])
	if count == 0:
		errors.append("no tiles")
		return errors
	var top := 0
	var far := Vector2i.ZERO
	for p in positions:
		top = maxi(top, p.z)
		far = Vector2i(maxi(far.x, p.x + 2), maxi(far.y, p.y + 2))
	if top + 1 > MAX_LAYERS:
		errors.append("%d layers, more than %d" % [top + 1, MAX_LAYERS])
	if far.x > MAX_WIDTH:
		errors.append("%d half-units wide, more than %d (tiles would be under 96 px)" % [far.x, MAX_WIDTH])
	if far.y > MAX_HEIGHT:
		errors.append("%d half-units tall, more than %d" % [far.y, MAX_HEIGHT])
	for i in count:
		var a := positions[i]
		for j in range(i + 1, count):
			var b := positions[j]
			if a.z != b.z or absi(a.y - b.y) >= 2:
				continue
			var dx := absi(a.x - b.x)
			if dx < 2:
				errors.append("tiles at %s and %s overlap" % [a, b])
			elif dx == 3:
				errors.append("tiles at %s and %s have a half-tile gap: it looks touching but does not block" % [a, b])
		if a.z > 0:
			for cell in [Vector2i(a.x, a.y), Vector2i(a.x + 1, a.y), Vector2i(a.x, a.y + 1), Vector2i(a.x + 1, a.y + 1)]:
				if not _rests_on_layer(positions, cell, a.z - 1):
					errors.append("tile at %s is not fully supported by layer %d" % [a, a.z - 1])
					break
	return errors


static func _rests_on_layer(positions: Array[Vector3i], cell: Vector2i, z: int) -> bool:
	for p in positions:
		if p.z == z and cell.x >= p.x and cell.x < p.x + 2 and cell.y >= p.y and cell.y < p.y + 2:
			return true
	return false
