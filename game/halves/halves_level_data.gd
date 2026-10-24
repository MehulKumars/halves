class_name HalvesLevelData
extends RefCounted
## One baked Halves level: tile positions and faces, the solution it was built from, and its bot
## stats and features. Made by HalvesLevels and HalvesPools from JSON and by the generator; the game
## screen asks it for a fresh HalvesState. Shuffle reseats into the solution when truly stuck.

var level: int = 0
## (v3) The place (1-15) the level belongs to; 0 in v2 files and pool boards.
var place: int = 0
var role: String = ""
var mask: String = ""
var seed_parts: Array = []
var positions: Array[Vector3i] = []
var faces: PackedInt32Array = PackedInt32Array()
var solution: Array[Vector2i] = []
## Lock groups, frost, mist, gold (HalvesFeatures format, normalised); {} for none.
var features: Dictionary = {}
## The tip card this level shows (HalvesTips id), "" for none.
var tip: String = ""
var stats: Dictionary = {}

var _geometry: HalvesGeometry


static func from_dict(entry: Dictionary) -> HalvesLevelData:
	var data := HalvesLevelData.new()
	data.level = int(entry.get("level", 0))
	data.place = int(entry.get("place", 0))
	data.role = str(entry.get("role", ""))
	data.mask = str(entry.get("mask", ""))
	for part: Variant in entry.get("seed_parts", []):
		data.seed_parts.append(int(part) if part is float else part)
	for tile: Variant in entry.get("tiles", []):
		var t: Array = tile
		data.positions.append(Vector3i(int(t[0]), int(t[1]), int(t[2])))
		data.faces.append(HalvesFace.from_text(str(t[3])))
	for step: Variant in entry.get("solution", []):
		var s: Array = step
		data.solution.append(Vector2i(int(s[0]), int(s[1])))
	data.features = HalvesFeatures.normalize(entry.get("features", {}))
	data.tip = str(entry.get("tip", ""))
	data.stats = entry.get("stats", {})
	return data


func to_dict() -> Dictionary:
	var tiles: Array = []
	for i in positions.size():
		var p := positions[i]
		tiles.append([p.x, p.y, p.z, HalvesFace.to_text(faces[i])])
	var steps: Array = []
	for pair in solution:
		steps.append([pair.x, pair.y])
	var out := {"level": level}
	if place > 0:
		out["place"] = place
	out["role"] = role
	out["mask"] = mask
	out["seed_parts"] = seed_parts
	out["tiles"] = tiles
	out["solution"] = steps
	if not features.is_empty():
		out["features"] = features
	if tip != "":
		out["tip"] = tip
	out["stats"] = stats
	return out


## The baked par time in ms (0 if the level has none).
func par_ms() -> int:
	return int(stats.get("par_ms", 0))


func geometry() -> HalvesGeometry:
	if _geometry == null:
		_geometry = HalvesGeometry.from_positions(positions)
		if not features.is_empty():
			_geometry = _geometry.with_features(features)
	return _geometry


func new_state() -> HalvesState:
	return HalvesState.new(geometry(), faces)
