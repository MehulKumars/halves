extends Node
## Debug-only console commands (autoload "DevTools"), built on LimboConsole.
## Removed in release builds. Open the console with the ` key on PC (or `adb shell input keyevent 68`),
## or tap with three fingers at once on a phone. Type `commands` to list everything.
## Prints one display summary at start-up so `adb logcat -s godot` shows the screen and safe area.

const TOGGLE_FINGERS: int = 3

var _touches: Dictionary[int, bool] = {}
var _log_input: bool = false
var _fps_layer: CanvasLayer
var _fps_label: Label
var _fps_timer: float = 0.0


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	set_process(false)
	LimboConsole.register_command(_cmd_set_seed, "set_seed", "override the level seed: set_seed <text>")
	LimboConsole.register_command(_cmd_skip_level, "skip_level", "finish the current level as a win")
	LimboConsole.register_command(_cmd_stats, "stats", "print the game's per-level records (best time, par, slips)")
	LimboConsole.register_command(_cmd_ads_grant, "ads_grant", "mock rewarded ads give rewards: ads_grant <true|false>")
	LimboConsole.register_command(_cmd_motion, "motion", "set motion scale 0..1 (0 = reduced motion)")
	LimboConsole.register_command(_cmd_reset_save, "reset_save", "delete the JSON save file")
	LimboConsole.register_command(_cmd_fps, "fps", "toggle the FPS, frame time and draw call overlay")
	LimboConsole.register_command(_cmd_log_input, "log_input", "toggle printing every key, touch and action event")
	LimboConsole.register_command(_cmd_display_info, "display_info", "print screen size, safe area and scale")
	LimboConsole.register_command(_cmd_safe_area, "safe_area",
		"fake a notch and gesture bar in canvas px: safe_area <left> <top> <right> <bottom> (all 0 = real)")
	if DisplayServer.get_name() != "headless":
		print(_display_summary())


func _input(event: InputEvent) -> void:
	if _log_input and not (event is InputEventMouseMotion or event is InputEventScreenDrag):
		print("[input] %s actions=%s" % [event.as_text(), _actions_of(event)])
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


func _notification(what: int) -> void:
	if _log_input and what == NOTIFICATION_WM_GO_BACK_REQUEST:
		print("[input] NOTIFICATION_WM_GO_BACK_REQUEST")


func _process(delta: float) -> void:
	_fps_timer -= delta
	if _fps_timer > 0.0:
		return
	_fps_timer = 0.5
	_fps_label.text = "%d fps  %.1f ms\n%d draw calls  %d MB" % [
		Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
	]


func _actions_of(event: InputEvent) -> Array[StringName]:
	var found: Array[StringName] = []
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_text") and event.is_action(action):
			found.append(action)
	return found


func _display_summary() -> String:
	var window := DisplayServer.window_get_size()
	return "[display] window %s, screen %s, canvas %s, safe area %s, insets %s, cutouts %s, %d dpi, %.0f Hz" % [
		window, DisplayServer.screen_get_size(), get_viewport().get_visible_rect().size,
		DisplayServer.get_display_safe_area(), SafeAreaMargin.get_insets(get_viewport()),
		DisplayServer.get_display_cutouts(), DisplayServer.screen_get_dpi(),
		DisplayServer.screen_get_refresh_rate(),
	]


func _cmd_set_seed(text: String) -> void:
	Events.debug_command.emit(&"set_seed", [text])
	LimboConsole.info("Seed override: %s" % text)


func _cmd_skip_level() -> void:
	Events.debug_command.emit(&"skip_level", [])
	LimboConsole.info("Requested skip_level")


func _cmd_stats() -> void:
	Events.debug_command.emit(&"stats", [])


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


func _cmd_fps() -> void:
	if _fps_layer == null:
		_fps_layer = CanvasLayer.new()
		_fps_layer.layer = 120
		_fps_label = Label.new()
		_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fps_label.add_theme_font_size_override("font_size", 24)
		_fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_fps_label.add_theme_constant_override("outline_size", 6)
		_fps_layer.add_child(_fps_label)
		add_child(_fps_layer)
	_fps_layer.visible = not is_processing()
	var insets := SafeAreaMargin.get_insets(get_viewport())
	_fps_label.position = Vector2(16 + insets.x, 16 + insets.y)
	_fps_timer = 0.0
	set_process(_fps_layer.visible)
	LimboConsole.info("FPS overlay: %s" % ("on" if _fps_layer.visible else "off"))


func _cmd_log_input() -> void:
	_log_input = not _log_input
	LimboConsole.info("Input logging: %s (see the output or adb logcat -s godot)" % _log_input)


func _cmd_display_info() -> void:
	LimboConsole.info(_display_summary())


func _cmd_safe_area(left: int, top: int, right: int, bottom: int) -> void:
	SafeAreaMargin.set_simulated_insets(get_tree(), Vector4i(left, top, right, bottom))
	LimboConsole.info("Simulated insets: %s" % SafeAreaMargin.simulated_insets)


## The FPS overlay for a settings switch (the same as the `fps` console command).
func set_fps_visible(visible: bool) -> void:
	if fps_visible() != visible:
		_cmd_fps()


func fps_visible() -> bool:
	return _fps_layer != null and _fps_layer.visible
