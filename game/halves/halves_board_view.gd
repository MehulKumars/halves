class_name HalvesBoardView
extends Control
## The Halves board: lays the tiles out to fit this Control, turns taps into HalvesState moves and
## plays the feedback (lift, snap, combo, mistake shake, shuffle flip, mist/lock/frost/gold, mend, lucky).
## The game screen calls setup(), show_hint(), undo() and shuffle(); the board signals what happened.

signal matched(a: int, b: int)
## A mistake was made; `forgiven` when the tutorial let it go without costing a star.
signal mistake_made(forgiven: bool)
## The two tiles of a mistake (for the run log), emitted with mistake_made.
signal mismatched(a: int, b: int)
## Stars, tiles or the undo history changed (HUD and booster badges refresh).
signal changed
signal stuck
signal cleared
## The first tap on this board (the clock starts here).
signal first_tap
## Snaps close together: `count` in a row (1 = no chain), at the snap point.
signal combo(count: int, at: Vector2)
## A tap on a tile that can't be played; `reason` is a HalvesGeometry.Block.
signal blocked_tap(tile: int, reason: int)
## A shuffle was applied: the board's shuffle counter (for shuffle_rng) and whether it was stuck.
signal shuffled(count: int, was_stuck: bool)
## Gold tiles cleared by a snap, at the snap point (board coordinates).
signal gold_collected(tiles: int, at: Vector2)
## (v3) A mend removed `a` and its mate `b` (for the run log).
signal mended(a: int, b: int)
## (v3) Clearing the gold pair earned a mend, at the snap point.
signal mend_earned(at: Vector2)
## (v3) Lucky tiles cleared in time by a snap or mend.
signal lucky_won(count: int, at: Vector2)

## Layout in units of the column pitch u: face size, row pitch, side depth, layer rise, lift.
const FACE_W: float = 0.96
const FACE_H: float = 1.11
const ROW_PITCH: float = 1.24
const SIDE_DEPTH: float = 0.09
const LAYER_RISE: float = 0.1
const LIFT: float = 0.125
## Small boards would get huge tiles; cap the pitch so level 1 still looks like a game.
const MAX_UNIT: float = 150.0
## The combo ladder stops climbing after this many semitones.
const MAX_COMBO_STEP: int = 9

var level_data: HalvesLevelData
var state: HalvesState
## Pulse the free mates of a picked tile (tutorial levels).
var show_mates: bool = false
## (v3) The next tap on a free tile mends it (set by the game screen's Mend button).
var mend_mode: bool = false
## (v3) A soft dark mat under the board, so tiles always sit on calm ground over the photo (the
## game screen turns it on; tip cards leave it off).
var show_mat: bool = false:
	set(value):
		show_mat = value
		queue_redraw()
var shuffles: int = 0
## The current chain of quick snaps (1 after a lone snap).
var combo_count: int = 0

var _tiles: Array[HalvesTileView] = []
var _selected: int = -1
var _guides: Array[int] = []
var _busy: bool = false
var _tapped: bool = false
var _last_snap_ms: int = -100000
var _unit: float = 100.0
var _origin: Vector2 = Vector2.ZERO
var _fx_layer: Node2D
var _shards: HalvesShardPool


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_fx_layer = Node2D.new()
	_fx_layer.z_index = 1
	add_child(_fx_layer)
	_shards = HalvesShardPool.new()
	_fx_layer.add_child(_shards)


func setup(data: HalvesLevelData, board_state: HalvesState) -> void:
	level_data = data
	state = board_state
	shuffles = 0
	combo_count = 0
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
	move_child(_fx_layer, -1)
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
		if HalvesBits.has(state.remaining, i) and _tiles[i].hit_rect().has_point(point):
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
	if _busy or state == null or not HalvesBits.has(state.remaining, i):
		return
	if not _tapped:
		_tapped = true
		first_tap.emit()
	_stop_guides()
	if not state.geometry.is_free(i, state.remaining):
		_nudge(i)
		return
	if mend_mode:
		_mend(i)
		return
	if _selected < 0:
		_select(i)
		return
	if _selected == i:
		_deselect()
		HalvesSfx.play(&"deselect")
		return
	var first := _selected
	var mistakes_before := state.mistakes
	var before := _snapshot()
	match state.try_pair(first, i):
		HalvesState.Result.MATCH:
			_on_match(first, i, before)
		HalvesState.Result.MISMATCH:
			_on_mistake(first, i, state.mistakes == mistakes_before)
		HalvesState.Result.SWITCH:
			_deselect()
			_select(i)
		_:
			_nudge(i)


## Mend mode: the free tile `i` and one of its mates, wherever it lies, snap together. The
## snap effect flies each half from its own place, so the mate visibly lifts out of the stack.
func _mend(i: int) -> void:
	_deselect()
	var before := _snapshot()
	if state.try_mend(i) != HalvesState.Result.MATCH:
		_nudge(i)
		return
	mend_mode = false
	var entry := state.last_action()
	_on_match(int(entry.a), int(entry.b), before, true)


## Highlights a pair until the next tap (Hint booster, tutorial).
func show_hint(pair: Vector2i) -> void:
	if pair.x < 0:
		return
	_stop_guides()
	_deselect()
	_guide(pair.x)
	_guide(pair.y)
	HalvesSfx.play(&"hint")


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
	combo_count = 0
	_refresh()
	HalvesSfx.play(&"undo")
	if last.kind == "pair" or last.kind == "mend":
		for i: int in [int(last.a), int(last.b)]:
			var tile := _tiles[i]
			if Juice.motion_scale > 0.0:
				tile.scale = Vector2.ONE * 0.6
				tile.create_tween().tween_property(tile, ^"scale", Vector2.ONE, 0.18) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	changed.emit()
	return true


## Re-deals the remaining tiles into a solvable board, with a quick flip. `was_stuck`: the board
## had no free pair when the shuffle was asked for (a slip).
func shuffle(was_stuck: bool = false) -> void:
	if _busy or state.is_cleared():
		return
	_stop_guides()
	_deselect()
	shuffles += 1
	combo_count = 0
	var before := state.remaining
	var result := HalvesFill.shuffle(state, level_data.solution, HalvesFill.shuffle_rng(level_data.level, shuffles))
	if result.is_empty():
		return
	state.apply_deal(result.remaining, result.faces, was_stuck)
	shuffled.emit(shuffles, was_stuck)
	HalvesSfx.play(&"shuffle")
	Haptics.tick()
	if Juice.motion_scale <= 0.0:
		_refresh()
		changed.emit()
		return
	_busy = true
	var involved: Array[HalvesTileView] = []
	var moved := HalvesBits.union(before, state.remaining)
	for tile in _tiles:
		if HalvesBits.has(moved, tile.index):
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
	HalvesSfx.play(&"select")
	if show_mates:
		_guide_mates(i)


func _deselect() -> void:
	if _selected < 0:
		return
	var tile := _tiles[_selected]
	tile.set_lifted(false, 0.0)
	tile.ring = HalvesTileView.Ring.NONE
	_selected = -1


func _on_match(a: int, b: int, before: Dictionary, mend: bool = false) -> void:
	var start_a := _tiles[a].position + Vector2(0, -_tiles[a].lift)
	var start_b := _tiles[b].position + Vector2(0, -_tiles[b].lift)
	var at := (start_a + start_b) * 0.5
	_selected = -1
	for i in [a, b]:
		_tiles[i].stop_ring()
		_tiles[i].lift = 0.0
	var now := Time.get_ticks_msec()
	combo_count = combo_count + 1 if now - _last_snap_ms <= int(HalvesConfig.COMBO_WINDOW * 1000.0) else 1
	_last_snap_ms = now
	var chain := mini(combo_count - 1, MAX_COMBO_STEP)
	var fx := HalvesSnapFx.new()
	_fx_layer.add_child(fx)
	var colour := HalvesPalette.face_color(state.faces[a])
	var burst := 1.0 + 0.12 * chain
	fx.snapped.connect(func(point: Vector2) -> void: _shards.burst(point, colour, _unit / 110.0, burst))
	fx.play(state.faces[a], state.faces[b], start_a, start_b, _tiles[a].face_size)
	Haptics.pulse(15 + 3 * mini(chain, 5))
	HalvesSfx.step(&"snap_big" if combo_count >= HalvesConfig.COMBO_COINS_AT else &"snap", chain)
	HalvesSfx.chime(state.faces[a])
	if mend:
		HalvesSfx.play(&"seam", 1.0, -6.0)
	_refresh()
	_feature_feedback(before, at, a, b)
	if combo_count >= 2:
		_float(at + Vector2(0, -_unit * 0.6), "×%d" % combo_count, HalvesPalette.SAND, 0.42)
	combo.emit(combo_count, at)
	if mend:
		mended.emit(a, b)
	else:
		matched.emit(a, b)
	changed.emit()
	if state.is_cleared():
		_busy = true
		await get_tree().create_timer(0.5, false).timeout
		if is_inside_tree():
			cleared.emit()
	else:
		_check_stuck_later()


## What a snap changed besides the pair: tiles that became free pop, mist lifts, locks open,
## frost thaws, gold pays.
func _feature_feedback(before: Dictionary, at: Vector2, a: int, b: int) -> void:
	var after := _snapshot()
	var freed := HalvesBits.intersection(HalvesBits.minus(after.free, before.free), state.remaining)
	var revealed := HalvesBits.minus(before.veiled, state.veiled)
	var opened := HalvesBits.minus(before.locked, after.locked)
	var thawed := HalvesBits.minus(before.frosted, after.frosted)
	for tile in _tiles:
		var i := tile.index
		if HalvesBits.has(revealed, i):
			tile.veiled = true
			tile.reveal()
		elif HalvesBits.has(freed, i):
			tile.pop()
		if HalvesBits.has(opened, i):
			tile.unlock()
		if HalvesBits.has(thawed, i):
			tile.thaw()
	if not HalvesBits.is_empty(revealed):
		HalvesSfx.play(&"reveal")
	if not HalvesBits.is_empty(opened):
		HalvesSfx.play(&"unlock")
		Haptics.success()
	if not HalvesBits.is_empty(thawed):
		HalvesSfx.play(&"thaw")
	var gold := HalvesBits.count(HalvesBits.intersection(state.gold, HalvesBits.of([a, b])))
	if gold > 0:
		HalvesSfx.play(&"gold")
		_float(at + Vector2(0, _unit * 0.2), "+%d" % (gold * HalvesConfig.GOLD_COINS), HalvesPalette.GOLD, 0.36)
		gold_collected.emit(gold, at)
	if state.mends > int(before.mends):
		HalvesSfx.play(&"gold")
		_float(at + Vector2(0, -_unit * 0.25), "+1 Mend", HalvesPalette.GOLD, 0.36)
		mend_earned.emit(at)
	var won := state.lucky_won - int(before.lucky_won)
	if won > 0:
		HalvesSfx.play(&"coin")
		_float(at + Vector2(0, _unit * 0.2), "+%d" % (won * HalvesConfig.LUCKY_COINS), HalvesPalette.GOLD, 0.36)
		lucky_won.emit(won, at)


func _on_mistake(a: int, b: int, forgiven: bool) -> void:
	_deselect()
	combo_count = 0
	for i in [a, b]:
		_tiles[i].shake(0.07 * _unit)
		_tiles[i].flash_ring(HalvesTileView.Ring.MISTAKE, 0.5)
	HalvesSfx.play(&"knock")
	Haptics.tick()
	mismatched.emit(a, b)
	mistake_made.emit(forgiven)
	changed.emit()
	if forgiven or show_mates:
		_guide_mates(a)


## Blocked tiles only bump: down when something lies on them, sideways when both sides are taken,
## a little shiver when a lock or frost holds them.
func _nudge(i: int) -> void:
	var reason := state.geometry.blocked_reason(i, state.remaining)
	match reason:
		HalvesGeometry.Block.COVERED:
			_tiles[i].shake(0.04 * _unit, Vector2.DOWN, 1)
		HalvesGeometry.Block.SIDES:
			_tiles[i].shake(0.04 * _unit, Vector2.RIGHT, 1)
		_:
			_tiles[i].shake(0.025 * _unit, Vector2.RIGHT, 2)
	HalvesSfx.play(&"blocked")
	blocked_tap.emit(i, reason)


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


func _float(at: Vector2, text: String, colour: Color, size_units: float) -> void:
	var label := HalvesFloatText.new()
	_fx_layer.add_child(label)
	label.play(at, text, colour, get_theme_font(&"font", &"Label"), maxi(28, roundi(_unit * size_units)))


func _layout() -> void:
	if state == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var bounds := state.geometry.bounds()
	var top_layer := state.geometry.max_z()
	_unit = unit_for(size, bounds, top_layer)
	_origin = ((size - board_size(_unit, bounds, top_layer)) * 0.5).floor()
	queue_redraw()
	for tile in _tiles:
		tile.face_size = Vector2(FACE_W, FACE_H) * _unit
		tile.depth = SIDE_DEPTH * _unit
		tile.layer_shade = maxf(0.6, 1.0 - 0.1 * (top_layer - state.geometry.positions[tile.index].z))
		tile.rest_position = tile_center(tile.index)
		tile.position = tile.rest_position
		if tile.index == _selected:
			tile.lift = LIFT * _unit


## The mat: the board's whole footprint plus a margin, rounded, a little darker than the photo.
func _draw() -> void:
	if not show_mat or state == null:
		return
	var bounds := state.geometry.bounds()
	var area := Rect2(_origin, board_size(_unit, bounds, state.geometry.max_z())).grow(_unit * 0.2)
	var mat := StyleBoxFlat.new()
	mat.bg_color = Color(0.03, 0.06, 0.11, 0.34)
	mat.border_color = Color(1.0, 1.0, 1.0, 0.07)
	mat.set_border_width_all(maxi(1, int(_unit * 0.02)))
	mat.set_corner_radius_all(int(_unit * 0.36))
	mat.anti_aliasing = true
	draw_style_box(mat, area)


## Free, veiled, locked and frosted tiles right now (HalvesBits sets), to see what a snap changed.
func _snapshot() -> Dictionary:
	var g := state.geometry
	var locked := HalvesBits.empty()
	var frosted := HalvesBits.empty()
	if not g.lock_need.is_empty():
		for i in g.size():
			if not HalvesBits.has(state.remaining, i):
				continue
			if HalvesBits.intersects(state.remaining, g.lock_need[i]):
				HalvesBits.set_bit(locked, i)
			if not HalvesBits.is_empty(g.frost_need[i]) and HalvesBits.is_subset(g.frost_need[i], state.remaining):
				HalvesBits.set_bit(frosted, i)
	return {"free": g.free_mask(state.remaining), "veiled": state.veiled, "locked": locked, "frosted": frosted,
			"mends": state.mends, "lucky_won": state.lucky_won}


## Redraws every tile after a look setting changed (bold tiles).
func refresh_look() -> void:
	_refresh()
	for tile in _tiles:
		tile.queue_redraw()


## Pairs left on a lucky tile's clock (section 1): -1 when it is not lucky, not free yet or over.
func _lucky_dots(i: int) -> int:
	if not HalvesBits.has(state.lucky, i) or not state.lucky_start.has(i):
		return -1
	var left := HalvesConfig.LUCKY_SNAPS - (state.pairs_done - state.lucky_start[i])
	return left if left > 0 else -1


func _refresh() -> void:
	var now := _snapshot()
	var keys := HalvesBits.empty()
	for group: Dictionary in state.geometry.features.get("locks", []):
		keys = HalvesBits.union(keys, HalvesFeatures.mask(group.keys))
	var turned := HalvesFeatures.mask(state.geometry.features.get("turned", []))
	for tile in _tiles:
		var i := tile.index
		var present := HalvesBits.has(state.remaining, i)
		tile.visible = present
		tile.face = state.faces[i]
		if present:
			tile.blocked = not HalvesBits.has(now.free, i)
			tile.veiled = HalvesBits.has(state.veiled, i)
			tile.key_mark = HalvesBits.has(keys, i)
			tile.lock_amount = 1.0 if HalvesBits.has(now.locked, i) else 0.0
			tile.frost = 1.0 if HalvesBits.has(now.frosted, i) else 0.0
			tile.gold = HalvesBits.has(state.gold, i)
			tile.turned = HalvesBits.has(turned, i)
			tile.lucky_dots = _lucky_dots(i)
