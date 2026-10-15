class_name SafeAreaMargin
extends MarginContainer
## Keeps its children clear of notches, camera cut-outs and system bars on phones.
## Put the HUD and menus inside one. On PC it only applies `extra_margin`.

@export var extra_margin: int = 0


func _ready() -> void:
	get_viewport().size_changed.connect(_apply)
	_apply()


func _apply() -> void:
	var left := extra_margin
	var top := extra_margin
	var right := extra_margin
	var bottom := extra_margin
	if OS.has_feature("mobile"):
		var safe: Rect2i = DisplayServer.get_display_safe_area()
		var window_size: Vector2i = DisplayServer.window_get_size()
		var visible_size: Vector2 = get_viewport().get_visible_rect().size
		if window_size.x > 0 and window_size.y > 0:
			var sx := visible_size.x / window_size.x
			var sy := visible_size.y / window_size.y
			left += int(safe.position.x * sx)
			top += int(safe.position.y * sy)
			right += int((window_size.x - safe.end.x) * sx)
			bottom += int((window_size.y - safe.end.y) * sy)
	add_theme_constant_override("margin_left", left)
	add_theme_constant_override("margin_top", top)
	add_theme_constant_override("margin_right", right)
	add_theme_constant_override("margin_bottom", bottom)
