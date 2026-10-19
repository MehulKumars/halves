class_name Settings
extends RefCounted
## The player's settings in one place, for the settings and pause popups and for game code.
## Volumes go through Maaack's AppSettings (bus volume, saved per bus in user://player_config.cfg);
## vibration, reduce motion and the game clock use GameSettings keys (AppLifecycle applies the first two).

const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"
const KEY_SHOW_TIMER: String = "ShowTimer"


## Linear volume 0..1 of an audio bus ("Music", "SFX", "Master").
static func volume(bus: StringName) -> float:
	var index := AudioServer.get_bus_index(bus)
	return AppSettings.get_bus_volume(index) if index >= 0 else 0.0


static func set_volume(bus: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	linear = clampf(linear, 0.0, 1.0)
	AppSettings.set_bus_volume(index, linear)
	PlayerConfig.set_config(AppSettings.AUDIO_SECTION, String(bus).to_pascal_case(), linear)


static func haptics() -> bool:
	return PlayerConfig.get_config(AppLifecycle.SECTION, AppLifecycle.KEY_HAPTICS, true)


static func set_haptics(enabled: bool) -> void:
	PlayerConfig.set_config(AppLifecycle.SECTION, AppLifecycle.KEY_HAPTICS, enabled)
	_apply()
	if enabled:
		Haptics.tick()


static func reduce_motion() -> bool:
	return PlayerConfig.get_config(AppLifecycle.SECTION, AppLifecycle.KEY_REDUCE_MOTION, false)


static func set_reduce_motion(enabled: bool) -> void:
	PlayerConfig.set_config(AppLifecycle.SECTION, AppLifecycle.KEY_REDUCE_MOTION, enabled)
	_apply()


## The clock in the game HUD (time is always recorded; this only hides it during play).
static func show_timer() -> bool:
	return PlayerConfig.get_config(AppLifecycle.SECTION, KEY_SHOW_TIMER, true)


static func set_show_timer(enabled: bool) -> void:
	PlayerConfig.set_config(AppLifecycle.SECTION, KEY_SHOW_TIMER, enabled)


static func _apply() -> void:
	AppLifecycle.apply_settings()
