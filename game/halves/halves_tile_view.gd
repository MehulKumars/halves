class_name HalvesTileView
extends Node2D
## One tile on the board: an ivory face over a dark side, with its half shape drawn in code.
## Made and laid out by HalvesBoardView; its origin is the face centre, so scale pops from the middle.
## Drawing is cached by Godot until a property here changes (queue_redraw), so idle tiles cost nothing.

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
## Where layout put the tile; shakes and nudges return here.
var rest_position: Vector2 = Vector2.ZERO

var _lift_tween: Tween
var _move_tween: Tween
var _ring_tween: Tween

static var _side_box: StyleBoxFlat = _make_box(HalvesPalette.SIDE)
static var _face_box: StyleBoxFlat = _make_box(HalvesPalette.IVORY)
static var _ring_box: StyleBoxFlat = _make_ring_box()


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
	HalvesShapes.draw_half(self, face, Vector2(0.0, top + h * 0.5), w * 0.31)
	if ring != Ring.NONE:
		var colour := HalvesPalette.TERRACOTTA if ring == Ring.MISTAKE else HalvesPalette.SAND
		colour.a = ring_alpha
		_ring_box.border_color = colour
		_ring_box.set_border_width_all(maxi(4, int(round(w * (0.065 if ring == Ring.SELECTED else 0.055)))))
		_ring_box.set_corner_radius_all(radius)
		draw_style_box(_ring_box, Rect2(-w * 0.5, top, w, h))


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
