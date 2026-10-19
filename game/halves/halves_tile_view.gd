class_name HalvesTileView
extends Node2D
## One tile on the board: an ivory face over a dark side, with its half shape drawn in code.
## Made and laid out by HalvesBoardView; its origin is the face centre, so scale pops from the middle.
## Feature overlays (mist veil, key, padlock, frost, gold) are drawn here too; idle tiles cost nothing
## because Godot caches the drawing until a property changes (queue_redraw).

enum Ring { NONE, SELECTED, HINT, MISTAKE }

var index: int = -1
var face: int = -1:
	set(value):
		face = value
		queue_redraw()
var face_size: Vector2 = Vector2(96, 111):
	set(value):
		face_size = value
		queue_redraw()
## Thickness of the dark side under the face, in pixels.
var depth: float = 9.0:
	set(value):
		depth = value
		queue_redraw()
## How far the face is raised (selected tiles lift), in pixels.
var lift: float = 0.0:
	set(value):
		lift = value
		queue_redraw()
var ring: Ring = Ring.NONE:
	set(value):
		ring = value
		queue_redraw()
var ring_alpha: float = 1.0:
	set(value):
		ring_alpha = value
		queue_redraw()
var blocked: bool = false:
	set(value):
		blocked = value
		_apply_tint()
## 1 on the top layer, darker below, so blocked tiles show how deep they sit (as in the sketch).
var layer_shade: float = 1.0:
	set(value):
		layer_shade = value
		_apply_tint()
## Feature overlays (see HalvesFeatures): a hidden face, a key, a padlock (0 = gone), frost (0 = thawed), gold.
var veiled: bool = false:
	set(value):
		veiled = value
		queue_redraw()
var key_mark: bool = false:
	set(value):
		key_mark = value
		queue_redraw()
var lock_amount: float = 0.0:
	set(value):
		lock_amount = value
		queue_redraw()
var frost: float = 0.0:
	set(value):
		frost = value
		queue_redraw()
var gold: bool = false:
	set(value):
		gold = value
		queue_redraw()
## Where layout put the tile; shakes and nudges return here.
var rest_position: Vector2 = Vector2.ZERO

var _lift_tween: Tween
var _move_tween: Tween
var _ring_tween: Tween
var _feature_tween: Tween
var _pop_tween: Tween

static var _side_box: StyleBoxFlat = _make_box(HalvesPalette.SIDE)
static var _face_box: StyleBoxFlat = _make_box(HalvesPalette.IVORY)
static var _ring_box: StyleBoxFlat = _make_ring_box()
static var _frost_box: StyleBoxFlat = _make_box(HalvesPalette.ICE)


## The tappable area in board coordinates (face plus side, following the lift).
func hit_rect() -> Rect2:
	return Rect2(position + Vector2(-face_size.x * 0.5, -face_size.y * 0.5 - lift), Vector2(face_size.x, face_size.y + depth + lift))


func set_lifted(lifted: bool, amount: float) -> void:
	if _lift_tween != null:
		_lift_tween.kill()
	var target := amount if lifted else 0.0
	if Juice.motion_scale <= 0.0:
		lift = target
		return
	_lift_tween = create_tween()
	_lift_tween.tween_property(self, ^"lift", target, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A soft looping glow and breath on the ring (hints, the tutorial pulse); steady without motion.
func pulse_ring(kind: Ring) -> void:
	stop_ring()
	ring = kind
	if Juice.motion_scale <= 0.0:
		return
	var grow := Vector2.ONE * (1.0 + 0.05 * Juice.motion_scale)
	_ring_tween = create_tween().set_loops()
	_ring_tween.tween_property(self, ^"ring_alpha", 0.3, 0.45).set_trans(Tween.TRANS_SINE)
	_ring_tween.parallel().tween_property(self, ^"scale", grow, 0.45).set_trans(Tween.TRANS_SINE)
	_ring_tween.tween_property(self, ^"ring_alpha", 1.0, 0.45).set_trans(Tween.TRANS_SINE)
	_ring_tween.parallel().tween_property(self, ^"scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)


func flash_ring(kind: Ring, seconds: float) -> void:
	stop_ring()
	ring = kind
	_ring_tween = create_tween()
	_ring_tween.tween_interval(seconds)
	_ring_tween.tween_callback(stop_ring)


func stop_ring() -> void:
	if _ring_tween != null:
		_ring_tween.kill()
		_ring_tween = null
		scale = Vector2.ONE
	ring_alpha = 1.0
	ring = Ring.NONE


## A short side-to-side shake (a mistake) or a small bump (a blocked tile), back to rest.
func shake(distance: float, along: Vector2 = Vector2.RIGHT, times: int = 2) -> void:
	if _move_tween != null:
		_move_tween.kill()
	position = rest_position
	if Juice.motion_scale <= 0.0:
		return
	var step := along.normalized() * distance * Juice.motion_scale
	_move_tween = create_tween()
	for i in times:
		_move_tween.tween_property(self, ^"position", rest_position + step, 0.04).set_trans(Tween.TRANS_SINE)
		_move_tween.tween_property(self, ^"position", rest_position - step * 0.6, 0.05).set_trans(Tween.TRANS_SINE)
	_move_tween.tween_property(self, ^"position", rest_position, 0.05).set_trans(Tween.TRANS_SINE)


func _draw() -> void:
	if face < 0:
		return
	var w := face_size.x
	var h := face_size.y
	var top := -h * 0.5 - lift
	var radius := int(round(w * 0.15))
	_side_box.set_corner_radius_all(radius)
	_face_box.set_corner_radius_all(radius)
	draw_style_box(_side_box, Rect2(-w * 0.5, top + depth, w, h + lift))
	draw_style_box(_face_box, Rect2(-w * 0.5, top, w, h))
	var face_rect := Rect2(-w * 0.5, top, w, h)
	if veiled:
		_draw_mist(face_rect)
	else:
		HalvesShapes.draw_half(self, face, Vector2(0.0, top + h * 0.5), w * 0.31)
	if frost > 0.0:
		_draw_frost(face_rect, radius)
	if gold:
		_draw_coin(Vector2(w * 0.5 - w * 0.15, top + w * 0.15), w * 0.1)
	if key_mark:
		_draw_key(Vector2(-w * 0.5 + w * 0.15, top + w * 0.15), w * 0.11)
	if lock_amount > 0.0:
		_draw_padlock(Vector2(0.0, top + h - w * 0.17), w * 0.13, lock_amount)
	if ring != Ring.NONE:
		var colour := HalvesPalette.TERRACOTTA if ring == Ring.MISTAKE else HalvesPalette.SAND
		colour.a = ring_alpha
		_ring_box.border_color = colour
		_ring_box.set_border_width_all(maxi(4, int(round(w * (0.065 if ring == Ring.SELECTED else 0.055)))))
		_ring_box.set_corner_radius_all(radius)
		draw_style_box(_ring_box, Rect2(-w * 0.5, top, w, h))


## A small pop when the tile becomes free (it can be played now).
func pop() -> void:
	if Juice.motion_scale <= 0.0:
		return
	if _pop_tween != null:
		_pop_tween.kill()
	scale = Vector2.ONE
	_pop_tween = create_tween()
	_pop_tween.tween_property(self, ^"scale", Vector2.ONE * (1.0 + 0.07 * Juice.motion_scale), 0.09) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pop_tween.tween_property(self, ^"scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Mist lifts: the tile flips and shows its face.
func reveal() -> void:
	if Juice.motion_scale <= 0.0:
		veiled = false
		return
	_kill_feature_tween()
	_feature_tween = create_tween()
	_feature_tween.tween_property(self, ^"scale:x", 0.0, 0.12).set_trans(Tween.TRANS_SINE)
	_feature_tween.tween_callback(func() -> void: veiled = false)
	_feature_tween.tween_property(self, ^"scale:x", 1.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The padlock pops open and fades.
func unlock() -> void:
	if Juice.motion_scale <= 0.0:
		lock_amount = 0.0
		return
	_kill_feature_tween()
	_feature_tween = create_tween()
	_feature_tween.tween_property(self, ^"lock_amount", 1.35, 0.1).set_trans(Tween.TRANS_SINE)
	_feature_tween.tween_property(self, ^"lock_amount", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## The frost cracks and melts away.
func thaw() -> void:
	if Juice.motion_scale <= 0.0:
		frost = 0.0
		return
	_kill_feature_tween()
	_feature_tween = create_tween()
	_feature_tween.tween_property(self, ^"frost", 1.25, 0.08)
	_feature_tween.tween_property(self, ^"frost", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _kill_feature_tween() -> void:
	if _feature_tween != null:
		_feature_tween.kill()
		_feature_tween = null
		scale = Vector2.ONE


## Mist: three soft waves across a pale face (the tile is there, its half is not shown yet).
func _draw_mist(rect: Rect2) -> void:
	var colour := HalvesPalette.MIST
	var waves := 3
	var width := maxf(2.0, rect.size.x * 0.045)
	for k in waves:
		var y := rect.position.y + rect.size.y * (0.3 + 0.2 * k)
		var points := PackedVector2Array()
		for s in 13:
			var t := s / 12.0
			var x := rect.position.x + rect.size.x * (0.16 + 0.68 * t)
			points.append(Vector2(x, y + sin(t * TAU * 1.5 + k) * rect.size.x * 0.035))
		draw_polyline(points, colour, width, true)


## Frost: an icy wash and rim, with small crystals in two corners; `frost` above 1 is the crack.
func _draw_frost(rect: Rect2, radius: int) -> void:
	var amount := minf(frost, 1.0)
	var wash := HalvesPalette.ICE
	wash.a = 0.32 * amount
	_frost_box.bg_color = wash
	_frost_box.border_color = Color(HalvesPalette.ICE_EDGE, 0.95 * amount)
	_frost_box.set_border_width_all(maxi(3, int(round(rect.size.x * 0.05))))
	_frost_box.set_corner_radius_all(radius)
	draw_style_box(_frost_box, rect)
	var arm := rect.size.x * 0.1
	var line := Color(HalvesPalette.ICE_EDGE, amount)
	for corner in [rect.position + Vector2(arm * 1.4, arm * 1.4), rect.end - Vector2(arm * 1.4, arm * 1.4)]:
		for k in 3:
			var d := Vector2.RIGHT.rotated(PI / 3.0 * k) * arm
			draw_line(corner - d, corner + d, line, maxf(2.0, rect.size.x * 0.025), true)
	if frost > 1.0:
		var crack := Color(1, 1, 1, (frost - 1.0) * 4.0)
		draw_polyline(PackedVector2Array([rect.position + rect.size * Vector2(0.2, 0.1),
				rect.position + rect.size * Vector2(0.45, 0.45), rect.position + rect.size * Vector2(0.4, 0.7),
				rect.position + rect.size * Vector2(0.7, 0.92)]), crack, maxf(2.0, rect.size.x * 0.03), true)


func _draw_coin(at: Vector2, r: float) -> void:
	draw_circle(at, r * 1.15, HalvesPalette.GOLD_DARK, true, -1.0, true)
	draw_circle(at, r, HalvesPalette.GOLD, true, -1.0, true)
	draw_circle(at + Vector2(-r * 0.3, -r * 0.3), r * 0.25, Color(1, 1, 1, 0.7), true, -1.0, true)


func _draw_key(at: Vector2, r: float) -> void:
	draw_circle(at, r * 1.25, HalvesPalette.SIDE, true, -1.0, true)
	var w := maxf(2.0, r * 0.28)
	draw_arc(at + Vector2(-r * 0.35, 0), r * 0.38, 0.0, TAU, 16, HalvesPalette.GOLD, w, true)
	draw_line(at + Vector2(0.0, 0), at + Vector2(r * 0.8, 0), HalvesPalette.GOLD, w, true)
	draw_line(at + Vector2(r * 0.55, 0), at + Vector2(r * 0.55, r * 0.4), HalvesPalette.GOLD, w, true)
	draw_line(at + Vector2(r * 0.8, 0), at + Vector2(r * 0.8, r * 0.3), HalvesPalette.GOLD, w, true)


## A padlock badge; `amount` 1 shown, 0 gone, above 1 the shackle springs up (opening).
func _draw_padlock(at: Vector2, r: float, amount: float) -> void:
	var alpha := clampf(amount, 0.0, 1.0)
	var lift_up := maxf(0.0, amount - 1.0) * r * 1.5
	draw_circle(at, r * 1.3, Color(HalvesPalette.SIDE, alpha), true, -1.0, true)
	var body := Rect2(at + Vector2(-r * 0.6, -r * 0.15), Vector2(r * 1.2, r * 0.9))
	draw_rect(body, Color(HalvesPalette.SAND, alpha))
	draw_arc(at + Vector2(0, -r * 0.2 - lift_up), r * 0.42, PI, TAU, 12, Color(HalvesPalette.SAND, alpha), maxf(2.0, r * 0.25), true)


func _apply_tint() -> void:
	if not blocked:
		modulate = Color.WHITE
		return
	var tint := HalvesPalette.BLOCKED_TINT * layer_shade
	tint.a = 1.0
	modulate = tint


static func _make_box(colour: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = colour
	box.anti_aliasing = true
	return box


static func _make_ring_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.anti_aliasing = true
	return box
