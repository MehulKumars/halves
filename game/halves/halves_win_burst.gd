class_name HalvesWinBurst
extends Node2D
## The board-clear celebration: a one-shot fountain of the chapter's ambient pieces (petals, rain
## sparkles, leaves, snow, fireflies) in its accent colour over the board, then frees itself.
## Spawned by the game screen; smaller with Reduce Motion off-scale, skipped at motion 0.

const AMOUNT: int = 56


## Bursts over `area` (global rect of the board) in the style of `chapter` (HalvesChapters entry).
func play(area: Rect2, chapter: Dictionary) -> void:
	z_index = 10
	if Juice.motion_scale <= 0.0:
		queue_free()
		return
	var kind: String = chapter.ambient
	var p := CPUParticles2D.new()
	p.texture = ChapterBackground.particle_texture("petals" if kind == "rain" else kind)
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = maxi(12, roundi(AMOUNT * Juice.motion_scale))
	p.lifetime = 1.6
	p.local_coords = false
	p.position = area.get_center() + Vector2(0, area.size.y * 0.25)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(area.size.x * 0.3, 10)
	p.direction = Vector2.UP
	p.spread = 55.0
	p.initial_velocity_min = 520.0
	p.initial_velocity_max = 900.0
	p.gravity = Vector2(0, 900)
	p.angular_velocity_min = -240.0
	p.angular_velocity_max = 240.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.scale_amount_min = 1.2
	p.scale_amount_max = 2.4
	var colours := Gradient.new()
	colours.set_color(0, chapter.accent)
	colours.set_color(1, Color(1.0, 0.95, 0.85))
	p.color_initial_ramp = colours
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.7, Color.WHITE)
	p.color_ramp = fade
	add_child(p)
	p.emitting = true
	await get_tree().create_timer(p.lifetime + 0.3, false).timeout
	queue_free()
