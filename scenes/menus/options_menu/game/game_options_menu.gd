extends Control

func _on_ResetGameControl_reset_confirmed() -> void:
	GameState.reset()


## Reduce Motion and Haptics toggles write to PlayerConfig; push them into Juice and Haptics.
func _on_feel_setting_changed(_value: Variant) -> void:
	AppLifecycle.apply_settings()
