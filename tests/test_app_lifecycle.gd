extends GutTest
## AppLifecycle applies the player's motion and haptics choices from PlayerConfig,
## and forwards Android lifecycle notifications to Events.

var _saved: Dictionary = {}


func before_each() -> void:
	for key: String in [AppLifecycle.KEY_REDUCE_MOTION, AppLifecycle.KEY_HAPTICS]:
		# ConfigFile logs an error when a missing key is read with a null default, so check first.
		if PlayerConfig.has_section_key(AppLifecycle.SECTION, key):
			_saved[key] = PlayerConfig.get_config(AppLifecycle.SECTION, key)
		else:
			_saved[key] = null


func after_each() -> void:
	for key: String in _saved:
		if _saved[key] == null:
			PlayerConfig.erase_section_key(AppLifecycle.SECTION, key)
		else:
			PlayerConfig.set_config(AppLifecycle.SECTION, key, _saved[key])
	AppLifecycle.apply_settings()


func test_defaults_are_full_motion_and_haptics_on() -> void:
	PlayerConfig.erase_section_key(AppLifecycle.SECTION, AppLifecycle.KEY_REDUCE_MOTION)
	PlayerConfig.erase_section_key(AppLifecycle.SECTION, AppLifecycle.KEY_HAPTICS)
	AppLifecycle.apply_settings()
	assert_eq(Juice.motion_scale, 1.0)
	assert_true(Haptics.enabled)


func test_player_choices_are_applied() -> void:
	PlayerConfig.set_config(AppLifecycle.SECTION, AppLifecycle.KEY_REDUCE_MOTION, true)
	PlayerConfig.set_config(AppLifecycle.SECTION, AppLifecycle.KEY_HAPTICS, false)
	AppLifecycle.apply_settings()
	assert_eq(Juice.motion_scale, 0.0)
	assert_false(Haptics.enabled)


func test_lifecycle_notifications_reach_events() -> void:
	watch_signals(Events)
	AppLifecycle.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	AppLifecycle.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	AppLifecycle.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_signal_emitted(Events, "app_paused")
	assert_signal_emitted(Events, "app_resumed")
	assert_signal_emitted(Events, "back_requested")
