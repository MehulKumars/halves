class_name HalvesBoardView
extends Control
## The Halves board: lays the tiles out to fit this Control, turns taps into HalvesState moves and
## plays the feedback (lift, snap, mistake shake, shuffle flip). The game screen calls setup(),
## show_hint(), undo() and shuffle(); the board signals matches, mistakes, stuck and cleared.

signal matched(a: int, b: int)
## A mistake was made; `forgiven` when the tutorial let it go without costing a star.
signal mistake_made(forgiven: bool)
## Stars, tiles or the undo history changed (HUD and booster badges refresh).
signal changed
signal stuck
signal cleared

## Layout in units of the column pitch u: face size, row pitch, side depth, layer rise, lift.
const FACE_W: float = 0.96
const FACE_H: float = 1.11
const ROW_PITCH: float = 1.24
const SIDE_DEPTH: float = 0.09
const LAYER_RISE: float = 0.1
const LIFT: float = 0.25
## Small boards would get huge tiles; cap the pitch so level 1 still looks like a game.
const MAX_UNIT: float = 150.0
## Settings.SFX_BUS, named here so the board compiles without autoloads (tools, tests).
const SFX_BUS: StringName = &"SFX"

## Sound slots for the human's porcelain and wood recordings (none shipped yet). WAV, on the SFX bus.
@export var select_sound: AudioStream
@export var snap_sound: AudioStream
@export var mistake_sound: AudioStream
@export var shuffle_sound: AudioStream

var level_data: HalvesLevelData
var state: HalvesState
## Pulse the free mates of a picked tile (tutorial levels).
var show_mates: bool = false
var shuffles: int = 0

var _tiles: Array[HalvesTileView] = []
var _selected: int = -1
var _guides: Array[int] = []
var _busy: bool = false
var _unit: float = 100.0
var _origin: Vector2 = Vector2.ZERO
var _fx_layer: Node2D
var _shards: HalvesShardPool
var _players: Array[AudioStreamPlayer] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_fx_layer = Node2D.new()
	_fx_layer.z_index = 1
	add_child(_fx_layer)
	_shards = HalvesShardPool.new()
	_fx_layer.add_child(_shards)
	for i in 4:
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_players.append(player)


func setup(data: HalvesLevelData, board_state: HalvesState) -> void:
	level_data = data
	state = board_state
	shuffles = 0
	_selected = -1
	_guides.clear()
	_busy = false
	for tile in _tiles:
		tile.queue_free()
	_tiles.clear()
	for i in data.positions.size():
		var tile := HalvesTileView.new()
		tile.index = i
		tile.face = state.faces[i]
		add_child(tile)
		_tiles.append(tile)
	_layout()
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


## The column pitch u that fits a board of `bounds` (half-units) and `top_layer` into `area`.
static func unit_for(area: Vector2, bounds: Rect2i, top_layer: int) -> float:
	var by_width := area.x / (bounds.size.x * 0.5)
	var by_height := area.y / (bounds.size.y * 0.5 * ROW_PITCH + LIFT + LAYER_RISE * top_layer)
	return minf(MAX_UNIT, minf(by_width, by_height))


static func board_size(unit: float, bounds: Rect2i, top_layer: int) -> Vector2:
	return Vector2(bounds.size.x * 0.5, bounds.size.y * 0.5 * ROW_PITCH + LIFT + LAYER_RISE * top_layer) * unit


## Width of a tile face in pixels with the current layout.
func face_width() -> float:
	return FACE_W * _unit


func tile_view(i: int) -> HalvesTileView:
	return _tiles[i]


func selected_tile() -> int:
	return _selected


func is_busy() -> bool:
	return _busy


## Centre of tile `i`'s face at rest, in board coordinates.
func tile_center(i: int) -> Vector2:
	var p := state.geometry.positions[i]
	var top_layer := state.geometry.max_z()
	var x := (p.x * 0.5 + 0.5) * _unit
	var y := (LIFT + LAYER_RISE * (top_layer - p.z) + p.y * 0.5 * ROW_PITCH + FACE_H * 0.5) * _unit
	return _origin + Vector2(x, y)


## The top-most remaining tile under `point` (board coordinates), or -1.
func tile_at(point: Vector2) -> int:
	if state == null:
		return -1
	for i in range(_tiles.size() - 1, -1, -1):
		if state.remaining & (1 << i) != 0 and _tiles[i].hit_rect().has_point(point):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press == null or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT:
		return
	var tile := tile_at(press.position)
	if tile >= 0:
		accept_event()
		tap(tile)


## What a tap on tile `i` does (also used by tests and the tutorial).
func tap(i: int) -> void:
	if _busy or state == null or state.remaining & (1 << i) == 0:
		return
	_stop_guides()
	if not state.geometry.is_free(i, state.remaining):
		_nudge(i)
		return
	if _selected < 0:
		_select(i)
		return
	if _selected == i:
		_deselect()
		return
	var first := _selected
	var mistakes_before := state.mistakes
	match state.try_pair(first, i):
		HalvesState.Result.MATCH:
			_on_match(first, i)
		HalvesState.Result.MISMATCH:
			_on_mistake(first, i, state.mistakes == mistakes_before)
		HalvesState.Result.SWITCH:
			_deselect()
			_select(i)
		_:
			_nudge(i)


## Highlights a pair until the next tap (Hint booster, tutorial).
func show_hint(pair: Vector2i) -> void:
	if pair.x < 0:
		return
	_stop_guides()
	_deselect()
	_guide(pair.x)
	_guide(pair.y)


## Level 1: one free tile whose mate is free pulses, no text.
func show_first_move() -> void:
	var pairs := state.free_pairs()
	if not pairs.is_empty():
		_guide(pairs[0].x)


## Takes back the last pair (the tiles return) or the last mistake (its star returns).
func undo() -> bool:
	if _busy or state.history.is_empty():
		return false
	_stop_guides()
	_deselect()
	var last := state.last_action()
	state.undo()
	_refresh()
	if last.kind == "pair":
		for i: int in [int(last.a), int(last.b)]:
			var tile := _tiles[i]
			if Juice.motion_scale > 0.0:
				tile.scale = Vector2.ONE * 0.6
				tile.create_tween().tween_property(tile, ^"scale", Vector2.ONE, 0.18) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	changed.emit()
	return true


## Re-deals the remaining tiles into a solvable board, with a quick flip.
func shuffle() -> void:
	if _busy or state.is_cleared():
		return
	_stop_guides()
	_deselect()
	shuffles += 1
	var before := state.remaining
	var result := HalvesFill.shuffle(state, level_data.solution, HalvesFill.shuffle_rng(level_data.level, shuffles))
	if result.is_empty():
		return
	state.apply_deal(result.remaining, result.faces)
	_play(shuffle_sound)
	Haptics.tick()
	if Juice.motion_scale <= 0.0:
		_refresh()
		changed.emit()
		return
	_busy = true
	var involved: Array[HalvesTileView] = []
	for tile in _tiles:
		if (before | state.remaining) & (1 << tile.index) != 0:
			involved.append(tile)
	var flip := create_tween().set_parallel()
	for tile in involved:
		flip.tween_property(tile, ^"scale:x", 0.0, 0.13).set_trans(Tween.TRANS_SINE)
	flip.chain().tween_callback(_refresh)
	for tile in involved:
		flip.parallel().tween_property(tile, ^"scale:x", 1.0, 0.15).set_trans(Tween.TRANS_SINE)
	await flip.finished
	_busy = false
	changed.emit()


func _select(i: int) -> void:
	_selected = i
	var tile := _tiles[i]
	tile.set_lifted(true, LIFT * _unit)
	tile.ring = HalvesTileView.Ring.SELECTED
	Haptics.tick()
	_play(select_sound)
	if show_mates:
		_guide_mates(i)


func _deselect() -> void:
	if _selected < 0:
		return
	var tile := _tiles[_selected]
	tile.set_lifted(false, 0.0)
	tile.ring = HalvesTileView.Ring.NONE
	_selected = -1


func _on_match(a: int, b: int) -> void:
	var start_a := _tiles[a].position + Vector2(0, -_tiles[a].lift)
	var start_b := _tiles[b].position + Vector2(0, -_tiles[b].lift)
	_selected = -1
	for i in [a, b]:
		_tiles[i].stop_ring()
		_tiles[i].lift = 0.0
	var fx := HalvesSnapFx.new()
	_fx_layer.add_child(fx)
	var colour := HalvesPalette.shape_color(HalvesFace.shape(state.faces[a]))
	fx.snapped.connect(func(at: Vector2) -> void: _shards.burst(at, colour, _unit / 110.0))
	fx.play(state.faces[a], state.faces[b], start_a, start_b, _tiles[a].face_size)
	Haptics.pulse(15)
	_play(snap_sound)
	_refresh()
	matched.emit(a, b)
	changed.emit()
	if state.is_cleared():
		_busy = true
		await get_tree().create_timer(0.5, false).timeout
		if is_inside_tree():
			cleared.emit()
	else:
		_check_stuck_later()


func _on_mistake(a: int, b: int, forgiven: bool) -> void:
	_deselect()
	for i in [a, b]:
		_tiles[i].shake(0.07 * _unit)
		_tiles[i].flash_ring(HalvesTileView.Ring.MISTAKE, 0.5)
	_play(mistake_sound)
	mistake_made.emit(forgiven)
	changed.emit()
	if forgiven or show_mates:
		_guide_mates(a)


## Blocked tiles only bump: down when something lies on them, sideways when both sides are taken.
func _nudge(i: int) -> void:
	var covered := state.remaining & state.geometry.cover[i] != 0
	_tiles[i].shake(0.04 * _unit, Vector2.DOWN if covered else Vector2.RIGHT, 1)


func _guide(i: int) -> void:
	if i < 0 or _guides.has(i):
		return
	_guides.append(i)
	_tiles[i].pulse_ring(HalvesTileView.Ring.HINT)


func _guide_mates(i: int) -> void:
	for j in state.geometry.free_tiles(state.remaining):
		if j != i and HalvesFace.matches(state.faces[i], state.faces[j]):
			_guide(j)


func _stop_guides() -> void:
	for i in _guides:
		if i != _selected:
			_tiles[i].stop_ring()
	_guides.clear()


func _check_stuck_later() -> void:
	await get_tree().create_timer(HalvesConfig.STUCK_DELAY, false).timeout
	if is_inside_tree() and not _busy and state.is_stuck():
		stuck.emit()


func _layout() -> void:
	if state == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var bounds := state.geometry.bounds()
	var top_layer := state.geometry.max_z()
	_unit = unit_for(size, bounds, top_layer)
	_origin = ((size - board_size(_unit, bounds, top_layer)) * 0.5).floor()
	for tile in _tiles:
		tile.face_size = Vector2(FACE_W, FACE_H) * _unit
		tile.depth = SIDE_DEPTH * _unit
		tile.layer_shade = maxf(0.6, 1.0 - 0.1 * (top_layer - state.geometry.positions[tile.index].z))
		tile.rest_position = tile_center(tile.index)
		tile.position = tile.rest_position
		if tile.index == _selected:
			tile.lift = LIFT * _unit


func _refresh() -> void:
	for tile in _tiles:
		var present := state.remaining & (1 << tile.index) != 0
		tile.visible = present
		tile.face = state.faces[tile.index]
		if present:
			tile.blocked = not state.geometry.is_free(tile.index, state.remaining)


func _play(stream: AudioStream) -> void:
	if stream == null:
		return
	for player in _players:
		if not player.playing:
			player.stream = stream
			player.pitch_scale = randf_range(0.96, 1.04)
			player.play()
			return
