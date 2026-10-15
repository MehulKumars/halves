class_name Screen
extends Control
## Base for full-screen pages (main menu, level select, shop, game). Handles Android Back
## and Escape: override on_back(), or set `back_scene` to go there. Popups get Back first
## (UI closes the top popup), so a screen only sees it when no popup is open.

## Screen to open on Back. Leave empty and override on_back() for anything else.
@export_file("*.tscn") var back_scene: String


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		on_back()


func on_back() -> void:
	if not back_scene.is_empty():
		UI.goto(back_scene)
