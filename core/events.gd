extends Node
## Global signal bus (autoload "Events").
## Systems talk through these signals instead of holding references to each other:
## parents call down into children, children and systems signal up through here.

@warning_ignore_start("unused_signal")
signal level_started(level_id: String)
signal level_finished(level_id: String, won: bool, stars: int)
signal results_shown(level_id: String, won: bool)
signal reward_granted(reward_id: String, amount: int)
signal setting_changed(key: StringName, value: Variant)
## Emitted by AppLifecycle. Save progress on app_paused: Android may kill a paused app.
signal app_paused
signal app_resumed
## Android Back button. On PC, Escape stays ui_cancel, which Maaack's menus already handle.
signal back_requested
## Emitted by DevTools console commands (debug builds only).
signal debug_command(command: StringName, args: Array)
@warning_ignore_restore("unused_signal")
