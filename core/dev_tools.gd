extends Node
## Debug-only console commands (autoload "DevTools"), built on LimboConsole.
## Removed in release builds. Open the console with the ` key on PC, or tap with
## three fingers at once on a phone. Type `commands` to list everything.

const TOGGLE_FINGERS: int = 3

var _touches: Dictionary[int, bool] = {}


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	LimboConsole.register_command(_cmd_set_seed, "set_seed", "override the level seed: set_seed <text>")
	LimboConsole.register_command(_cmd_skip_level, "skip_level", "finish the current level as a win")
	LimboConsole.register_command(_cmd_ads_grant, "ads_grant", "mock rewarded ads give rewards: ads_grant <true|false>")
	LimboConsole.register_command(_cmd_motion, "motion", "set motion scale 0..1 (0 = reduced motion)")
	LimboConsole.register_command(_cmd_reset_save, "reset_save", "delete the JSON save file")


func _input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch == null:
		return
	if touch.pressed:
		_touches[touch.index] = true
		if _touches.size() >= TOGGLE_FINGERS:
			_touches.clear()
			LimboConsole.toggle_console()
	else:
		_touches.erase(touch.index)


func _cmd_set_seed(text: String) -> void:
	Events.debug_command.emit(&"set_seed", [text])
	LimboConsole.info("Seed override: %s" % text)


func _cmd_skip_level() -> void:
	Events.debug_command.emit(&"skip_level", [])
	LimboConsole.info("Requested skip_level")


func _cmd_ads_grant(grant: bool) -> void:
	var mock := Services.ads as MockAdsService
	if mock == null:
		LimboConsole.info("Live ad service is not the mock; nothing changed")
		return
	mock.grant_rewards = grant
	LimboConsole.info("Mock rewarded ads grant rewards: %s" % grant)


func _cmd_motion(motion_scale: float) -> void:
	Juice.motion_scale = clampf(motion_scale, 0.0, 1.0)
	LimboConsole.info("Motion scale: %.2f" % Juice.motion_scale)


func _cmd_reset_save() -> void:
	SaveStore.delete_save()
	LimboConsole.info("Deleted %s" % SaveStore.DEFAULT_PATH)
