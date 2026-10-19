class_name HalvesShardPool
extends Node2D
## A small pool of one-shot CPUParticles2D bursts (12 shards each) for the snap moment.
## Owned by HalvesBoardView; restart() reuses an emitter, so no nodes are made during play.
## GPUParticles2D.emit_particle() does not work in the Compatibility renderer; CPU bursts do.

const POOL_SIZE: int = 4
const SHARDS: int = 12
## Bursts grow with combos but never past this many shards.
const MAX_SHARDS: int = 28

var _emitters: Array[CPUParticles2D] = []
var _next: int = 0


func _init() -> void:
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	for i in POOL_SIZE:
		var emitter := CPUParticles2D.new()
		emitter.emitting = false
		emitter.one_shot = true
		emitter.explosiveness = 1.0
		emitter.amount = SHARDS
		emitter.lifetime = 0.55
		emitter.local_coords = false
		emitter.direction = Vector2.UP
		emitter.spread = 180.0
		emitter.gravity = Vector2(0, 620)
		emitter.initial_velocity_min = 160.0
		emitter.initial_velocity_max = 320.0
		emitter.angle_min = 0.0
		emitter.angle_max = 360.0
		emitter.scale_amount_min = 5.0
		emitter.scale_amount_max = 10.0
		emitter.color_ramp = fade
		add_child(emitter)
		_emitters.append(emitter)


## Throws shards in sand and the shape's colour from `at` (pool coordinates); `amount_scale` grows
## the burst along a combo chain. Off without motion.
func burst(at: Vector2, colour: Color, size_scale: float = 1.0, amount_scale: float = 1.0) -> void:
	if Juice.motion_scale <= 0.0:
		return
	var emitter := _emitters[_next]
	_next = (_next + 1) % POOL_SIZE
	var colours := Gradient.new()
	colours.set_color(0, HalvesPalette.SAND)
	colours.set_color(1, colour)
	emitter.color_initial_ramp = colours
	emitter.amount = clampi(roundi(SHARDS * amount_scale * Juice.motion_scale), 4, MAX_SHARDS)
	emitter.initial_velocity_min = 160.0 * size_scale
	emitter.initial_velocity_max = 320.0 * size_scale
	emitter.scale_amount_min = 5.0 * size_scale
	emitter.scale_amount_max = 10.0 * size_scale
	emitter.position = at
	emitter.restart()
