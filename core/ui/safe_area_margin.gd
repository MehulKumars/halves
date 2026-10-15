class_name SafeAreaMargin
extends MarginContainer
## Keeps its children clear of notches, camera holes, rounded corners and the gesture bar.
## Used by the main menu and level HUDs; wrap any full-screen UI in one. On PC it only adds
## `extra_margin`, unless `simulated_insets` is set (snapshots and the `safe_area` command).

const GROUP: StringName = &"safe_area_margins"

## Insets in canvas pixels (left, top, right, bottom) used instead of the phone's safe area.
## Zero means "use the real one". Change it with set_simulated_insets() so open screens update.
static var simulated_insets: Vector4i = Vector4i.ZERO

## Margin added on every side, on top of the safe-area insets.
@export var extra_margin: int = 0


## Fakes a notch and gesture bar on PC, and re-lays out every SafeAreaMargin in the tree.
static func set_simulated_insets(tree: SceneTree, insets: Vector4i) -> void:
	simulated_insets = insets
	tree.call_group(GROUP, &"refresh")


## The safe-area insets of the screen in canvas pixels: x = left, y = top, z = right, w = bottom.
static func get_insets(viewport: Viewport) -> Vector4i:
	if simulated_insets != Vector4i.ZERO:
		return simulated_insets
	if not OS.has_feature("mobile"):
		return Vector4i.ZERO
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var window_size: Vector2i = DisplayServer.window_get_size()
	if window_size.x <= 0 or window_size.y <= 0 or safe.size == Vector2i.ZERO:
		return Vector4i.ZERO
	var visible_size: Vector2 = viewport.get_visible_rect().size
	var sx := visible_size.x / window_size.x
	var sy := visible_size.y / window_size.y
	return Vector4i(
		maxi(0, ceili(safe.position.x * sx)),
		maxi(0, ceili(safe.position.y * sy)),
		maxi(0, ceili((window_size.x - safe.end.x) * sx)),
		maxi(0, ceili((window_size.y - safe.end.y) * sy)))


func _ready() -> void:
	add_to_group(GROUP)
	get_viewport().size_changed.connect(refresh)
	refresh()


## Re-reads the insets and applies them. Called on resize and by set_simulated_insets().
func refresh() -> void:
	var insets := get_insets(get_viewport())
	add_theme_constant_override("margin_left", extra_margin + insets.x)
	add_theme_constant_override("margin_top", extra_margin + insets.y)
	add_theme_constant_override("margin_right", extra_margin + insets.z)
	add_theme_constant_override("margin_bottom", extra_margin + insets.w)
