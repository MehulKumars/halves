class_name HalvesLevelData
extends RefCounted
## One baked Halves level: tile positions and faces, the solution it was built from, and its bot
## stats. Made by HalvesLevels from the JSON file and by the generator; the game screen asks it for
## a fresh HalvesState. The solution is also what Shuffle reseats into when a board is truly stuck.

var level: int = 0
var role: String = ""
var mask: String = ""
var seed_parts: Array = []
var positions: Array[Vector3i] = []
var faces: PackedInt32Array = PackedInt32Array()
var solution: Array[Vector2i] = []
var stats: Dictionary = {}

var _geometry: HalvesGeometry


static func from_dict(entry: Dictionary) -> HalvesLevelData:
	var data := HalvesLevelData.new()
	data.level = int(entry.get("level", 0))
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
	return {
		"level": level,
		"role": role,
		"mask": mask,
		"seed_parts": seed_parts,
		"tiles": tiles,
		"solution": steps,
		"stats": stats,
	}


func geometry() -> HalvesGeometry:
	if _geometry == null:
		_geometry = HalvesGeometry.from_positions(positions)
	return _geometry


func new_state() -> HalvesState:
	return HalvesState.new(geometry(), faces)
