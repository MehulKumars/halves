extends Node
## App lifecycle and player feel settings (autoload "AppLifecycle").
## Turns Android lifecycle notifications into Events signals, and applies the player's
## motion and haptics choices from Maaack's PlayerConfig (user://player_config.cfg).
##
## Games: save progress on Events.app_paused (Android may kill a paused app without
## warning), and open the pause menu or go back one screen on Events.back_requested.
## project.godot sets application/config/quit_on_go_back=false so Back does not quit.
## Options menu: bind OptionControls to section "GameSettings", keys "ReduceMotion" and
## "Haptics", then call AppLifecycle.apply_settings() when the menu closes.

const SECTION: String = "GameSettings"
const KEY_REDUCE_MOTION: String = "ReduceMotion"
const KEY_HAPTICS: String = "Haptics"


func _ready() -> void:
	apply_settings()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			Events.app_paused.emit()
		NOTIFICATION_APPLICATION_RESUMED:
			apply_settings()
			Events.app_resumed.emit()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			Events.back_requested.emit()


## Reads the player's choices and pushes them into Juice and Haptics.
func apply_settings() -> void:
	var reduce_motion: bool = PlayerConfig.get_config(SECTION, KEY_REDUCE_MOTION, false)
	Juice.motion_scale = 0.0 if reduce_motion else 1.0
	Haptics.enabled = PlayerConfig.get_config(SECTION, KEY_HAPTICS, true)
