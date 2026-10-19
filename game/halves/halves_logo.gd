class_name HalvesLogo
extends Control
## The Halves mark drawn with the game's own tile art: two ivory tiles carrying mirror halves of a
## circle; `join` 0 shows them apart, 1 snapped into one card with the whole shape. The splash
## animates it (snap()), the main menu shows it joined. Sized by custom_minimum_size.

signal snapped

## 0 = two tiles apart, 1 = one card with the whole circle.
var join: float = 1.0:
	set(value):
		join = value
		queue_redraw()
## 0..1 slide-in of the two tiles from the sides before they meet.
var arrive: float = 1.0:
	set(value):
		arrive = value
		queue_redraw()

static var _face: StyleBoxFlat = _box(HalvesPalette.IVORY)
static var _side: StyleBoxFlat = _box(HalvesPalette.SIDE)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(220, 170)


## Tiles slide in, meet and snap (with a burst from `shards` if given). Instant with Reduce Motion.
func snap(seconds: float = 0.9) -> void:
	if Juice.motion_scale <= 0.0:
		arrive = 1.0
		join = 1.0
		snapped.emit()
		return
	arrive = 0.0
	join = 0.0
	var tween := create_tween()
	tween.tween_property(self, ^"arrive", 1.0, seconds * 0.55).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: snapped.emit())
	tween.tween_property(self, ^"join", 1.0, seconds * 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished


func _draw() -> void:
	var tile_h := size.y * 0.78
	var tile_w := tile_h * 0.86
	var radius := int(round(tile_w * 0.15))
	var depth := tile_w * 0.09
	var centre := size * 0.5 - Vector2(0, depth * 0.5)
	var extent := tile_w * 0.36
	var face_a := HalvesFace.make(HalvesFace.Shape.CIRCLE, HalvesFace.Cut.VERTICAL, HalvesFace.Mark.NONE, HalvesFace.SIDE_A)
	_face.set_corner_radius_all(radius)
	_side.set_corner_radius_all(radius)
	if join <= 0.0:
		# Two tiles slide in from the sides until they touch (their half shapes 1.12 tiles apart).
		var spread := lerpf(size.x * 0.5 + tile_w, tile_w * 0.56, arrive)
		for side in [-1.0, 1.0]:
			var at := centre + Vector2(spread * side, 0)
			var rect := Rect2(at - Vector2(tile_w, tile_h) * 0.5, Vector2(tile_w, tile_h))
			draw_style_box(_side, Rect2(rect.position + Vector2(0, depth), rect.size))
			draw_style_box(_face, rect)
			var face := face_a if side < 0.0 else face_a | HalvesFace.SIDE_B
			HalvesShapes.draw_half(self, face, at, extent)
		return
	# The two tiles melt into one card while the gap between the halves closes.
	var card := Vector2(lerpf(tile_w * 2.12, tile_w * 1.3, join), lerpf(tile_h, tile_h * 0.92, join))
	var rect := Rect2(centre - card * 0.5, card)
	draw_style_box(_side, Rect2(rect.position + Vector2(0, depth), rect.size))
	draw_style_box(_face, rect)
	HalvesShapes.draw_whole(self, HalvesFace.pair_key(face_a), centre, extent, lerpf(tile_w * 1.12, 3.0, join))


static func _box(colour: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = colour
	box.anti_aliasing = true
	return box
