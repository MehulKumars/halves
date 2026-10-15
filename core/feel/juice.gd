class_name Juice
extends RefCounted
## Small reusable feedback tweens. Put juice on player successes; keep calm games calm.
## All effects scale with `motion_scale` (0 = reduced motion, 0.5 = gentle, 1 = full).
## Controls scale from their pivot: set pivot_offset to the centre before popping a Control.
## Rapid repeats are safe: a new effect on a node first snaps it back to the scale it had
## before the interrupted effect, so repeated pops never leave it permanently enlarged.

## Mirror the player's "Reduce motion" setting here (AppLifecycle does this).
static var motion_scale: float = 1.0

static var _active_tween: Dictionary[int, Tween] = {}
static var _rest_scale: Dictionary[int, Vector2] = {}


## Quick grow-and-settle, e.g. when a tile is tapped or a reward appears.
static func pop(target: Node, peak: float = 1.08, duration: float = 0.12) -> Tween:
	if not _can_animate(target):
		return null
	var tween := _new_tween(target)
	var base: Vector2 = _rest_scale[target.get_instance_id()]
	var amount := 1.0 + (peak - 1.0) * motion_scale
	tween.tween_property(target, "scale", base * amount, duration * 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "scale", base, duration * 0.6) \
		.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	return tween


## Squash then spring back, e.g. when two pieces snap together.
static func squash(target: Node, squash_scale: Vector2 = Vector2(1.12, 0.9), duration: float = 0.14) -> Tween:
	if not _can_animate(target):
		return null
	var tween := _new_tween(target)
	var base: Vector2 = _rest_scale[target.get_instance_id()]
	var amount := Vector2.ONE + (squash_scale - Vector2.ONE) * motion_scale
	tween.tween_property(target, "scale", base * amount, duration * 0.35) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "scale", base, duration * 0.65) \
		.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	return tween


static func _can_animate(target: Node) -> bool:
	return motion_scale > 0.0 and is_instance_valid(target) and "scale" in target


## Kills an in-flight effect on the node (restoring its rest scale) and starts a new tween.
static func _new_tween(target: Node) -> Tween:
	var id := target.get_instance_id()
	var old: Tween = _active_tween.get(id)
	if old != null and old.is_valid():
		old.kill()
		target.set("scale", _rest_scale[id])
	else:
		_rest_scale[id] = target.get("scale")
	var tween := target.create_tween()
	_active_tween[id] = tween
	tween.finished.connect(func() -> void:
		_active_tween.erase(id)
		_rest_scale.erase(id))
	return tween
