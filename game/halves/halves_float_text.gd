class_name HalvesFloatText
extends Node2D
## A short word or number that rises and fades over the board ("x3", "+5"): combo and gold
## feedback. Spawned by HalvesBoardView on its effect layer; frees itself. Off without motion
## except for a brief still label, so the information still shows.

var text: String = ""
var colour: Color = Color.WHITE
var font: Font
var font_size: int = 40


func play(at: Vector2, label: String, tint: Color, label_font: Font, size: int) -> void:
	position = at
	text = label
	colour = tint
	font = label_font
	font_size = size
	queue_redraw()
	var tween := create_tween()
	if Juice.motion_scale > 0.0:
		scale = Vector2.ONE * 0.6
		tween.tween_property(self, ^"scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(self, ^"position:y", at.y - font_size * 1.6, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, ^"modulate:a", 0.0, 0.25)
	else:
		tween.tween_interval(0.6)
	tween.tween_callback(queue_free)


func _draw() -> void:
	if font == null or text.is_empty():
		return
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var base := Vector2(-width * 0.5, font_size * 0.35)
	draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(4, font_size / 7), HalvesPalette.SIDE)
	draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)
