class_name JourneyPath
extends Control
## One place's stretch of the journey map: its levels as stepping stones on a winding trail
## (LevelTiles left and right of a drifting centre line, joined by a dotted curve).
## Built by the level select screen; tiles stay at least 96 px and never overlap.

## Vertical distance between stones; alternate stones sit far apart sideways, so this can be
## less than a tile's height.
const STEP: float = 84.0
const TILE := Vector2(116, 124)
const PAD: float = 24.0

var _tiles: Array[LevelTile] = []
var _phase: float = 0.0


## Adds a stone per level (first..last); `next` is the level Play would start.
func build(first: int, last: int, next: int, phase: float, make_tile: Callable) -> void:
	_phase = phase
	for level in range(first, last + 1):
		var tile: LevelTile = make_tile.call(level, next)
		add_child(tile)
		# After add_child: LevelTile._ready sets its own grid height, which a stone must not have.
		tile.custom_minimum_size = TILE
		tile.size = TILE
		_tiles.append(tile)
	custom_minimum_size.y = PAD * 2.0 + STEP * maxi(0, _tiles.size() - 1) + TILE.y
	_place()


## The tile of `level`, if it is on this stretch (to scroll to it).
func tile_for(level: int) -> LevelTile:
	for tile in _tiles:
		if tile.level == level:
			return tile
	return null


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place()


func _place() -> void:
	for k in _tiles.size():
		_tiles[k].position = _centre(k) - TILE * 0.5
	queue_redraw()


## Stone k's centre: alternately left and right of a centre line that drifts slowly.
func _centre(k: int) -> Vector2:
	var swing := clampf(size.x * 0.22, TILE.x * 0.62, 150.0)
	var drift := sin(_phase + k * 0.45) * minf(size.x * 0.08, 50.0)
	var side := -1.0 if k % 2 == 0 else 1.0
	return Vector2(size.x * 0.5 + side * swing + drift, PAD + TILE.y * 0.5 + STEP * k)


## The trail: small dots along a smooth curve through the stones' centres.
func _draw() -> void:
	if _tiles.size() < 2:
		return
	var curve := Curve2D.new()
	for k in _tiles.size():
		var at := _centre(k)
		var bend := Vector2(0.0, STEP * 0.45)
		curve.add_point(at, -bend, bend)
	var colour := get_theme_color(&"text_on_bg", &"Tokens")
	colour.a = 0.45
	var length := curve.get_baked_length()
	var gap := 18.0
	var d := 0.0
	while d < length:
		draw_circle(curve.sample_baked(d), 3.5, colour, true, -1.0, true)
		d += gap
