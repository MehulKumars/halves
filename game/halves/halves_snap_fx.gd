class_name HalvesSnapFx
extends Node2D
## The snap: the two matched halves fly together, join into the whole shape on an ivory card,
## squash, throw sand speed lines and sparkles, then fade. Spawned by HalvesBoardView per match.
## With Reduce Motion the whole card just shows for a moment; the tiles have already left the board.

## Fires when the halves meet (the board bursts its shards here).
signal snapped(at: Vector2)

const FLY_TIME: float = 0.16
const JOIN_TIME: float = 0.12
const HOLD_TIME: float = 0.12
const FADE_TIME: float = 0.2

var face_a: int = -1
var face_b: int = -1
var face_size: Vector2 = Vector2(96, 111)
var from_a: Vector2 = Vector2.ZERO
var from_b: Vector2 = Vector2.ZERO

## 0..1 while the halves fly in; then 0..1 while the joined card closes its gap.
var flight: float = 0.0:
	set(value):
		flight = value
		queue_redraw()
var join: float = 0.0:
	set(value):
		join = value
		queue_redraw()

static var _card_box: StyleBoxFlat = _box(HalvesPalette.IVORY)
static var _side_box: StyleBoxFlat = _box(HalvesPalette.SIDE)
static var _tile_box: StyleBoxFlat = _box(HalvesPalette.IVORY)


## Starts the effect between two tile centres (board coordinates); frees itself when done.
func play(a: int, b: int, start_a: Vector2, start_b: Vector2, size: Vector2) -> void:
	face_a = a
	face_b = b
	face_size = size
	position = (start_a + start_b) * 0.5
	from_a = start_a - position
	from_b = start_b - position
	if Juice.motion_scale <= 0.0:
		flight = 1.0
		join = 1.0
		snapped.emit(position)
		await get_tree().create_timer(0.3, false).timeout
		queue_free()
		return
	var tween := create_tween()
	tween.tween_property(self, ^"flight", 1.0, FLY_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_on_meet)
	tween.tween_property(self, ^"join", 1.0, JOIN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(HOLD_TIME)
	tween.tween_property(self, ^"modulate:a", 0.0, FADE_TIME)
	tween.parallel().tween_property(self, ^"scale", Vector2.ONE * (1.0 + 0.1 * Juice.motion_scale), FADE_TIME)
	tween.tween_callback(queue_free)


func _on_meet() -> void:
	snapped.emit(position)
	Juice.squash(self, Vector2(1.16, 0.86), 0.22)


func _draw() -> void:
	var extent := face_size.x * 0.31
	var radius := int(round(face_size.x * 0.15))
	if join <= 0.0:
		# Two small tiles on their way to the middle.
		_tile_box.set_corner_radius_all(radius)
		for pair in [[face_a, from_a], [face_b, from_b]]:
			var centre: Vector2 = (pair[1] as Vector2).lerp(Vector2.ZERO, flight)
			var size := face_size * lerpf(1.0, 0.9, flight)
			draw_style_box(_tile_box, Rect2(centre - size * 0.5, size))
			HalvesShapes.draw_half(self, pair[0], centre, extent * lerpf(1.0, 0.9, flight))
		return
	# The joined card with the whole shape; the gap between the halves closes as `join` grows.
	var card := Vector2(face_size.x * 1.3, face_size.y * 0.9)
	var depth := face_size.x * 0.09
	_card_box.set_corner_radius_all(radius)
	_side_box.set_corner_radius_all(radius)
	draw_style_box(_side_box, Rect2(-card * 0.5 + Vector2(0, depth), card))
	draw_style_box(_card_box, Rect2(-card * 0.5, card))
	var key := HalvesFace.pair_key(face_a)
	HalvesShapes.draw_whole(self, key, Vector2.ZERO, extent * 1.1, lerpf(face_size.x * 0.12, 3.0, join))
	# Sand speed lines along the cut direction, and four sparkles at the corners.
	var vertical := HalvesFace.cut(face_a) == HalvesFace.Cut.VERTICAL
	var reach := (card.x if vertical else card.y) * 0.5
	var along := Vector2.RIGHT if vertical else Vector2.DOWN
	var length := face_size.x * 0.22 * (1.0 - join * 0.5)
	var width := maxf(3.0, face_size.x * 0.05)
	for direction in [-1.0, 1.0]:
		var start: Vector2 = along * direction * (reach + face_size.x * 0.08)
		draw_line(start, start + along * direction * length, HalvesPalette.SAND, width, true)
	var spark := maxf(3.0, face_size.x * 0.045)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var spot: Vector2 = corner * (card * 0.5 + Vector2.ONE * face_size.x * 0.1 * join)
		draw_circle(spot, spark, HalvesPalette.SAND, true, -1.0, true)


static func _box(colour: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = colour
	box.anti_aliasing = true
	return box
