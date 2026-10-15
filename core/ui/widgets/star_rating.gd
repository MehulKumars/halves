@tool
class_name StarRating
extends HBoxContainer
## Up to three stars: earned ones in the style's gold, the rest as outlines.
## Used by level tiles and the results popup; reveal() pops them in one by one.

@export_range(0, 3) var stars: int = 0:
	set(value):
		stars = clampi(value, 0, 3)
		_refresh()
@export var star_size: float = 56.0:
	set(value):
		star_size = value
		_refresh()
## Bigger middle star, as on most results screens.
@export var raise_middle: bool = false:
	set(value):
		raise_middle = value
		_refresh()

var _icons: Array[TextureRect] = []


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_refresh()


## Shows `count` stars one after another with a pop and a haptic tick each.
func reveal(count: int, delay: float = 0.25) -> void:
	stars = 0
	for i in clampi(count, 0, 3):
		await get_tree().create_timer(delay, true, false, true).timeout
		if not is_inside_tree():
			return
		stars = i + 1
		_icons[i].pivot_offset_ratio = Vector2(0.5, 0.5)
		Juice.pop(_icons[i], 1.35, 0.3)
		Haptics.tick()


func _refresh() -> void:
	if not is_inside_tree():
		return
	while _icons.size() < 3:
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icon)
		_icons.append(icon)
	var gold := get_theme_color(&"gold", &"Tokens")
	var empty := get_theme_color(&"text_muted", &"Tokens")
	for i in 3:
		var big := raise_middle and i == 1
		_icons[i].custom_minimum_size = Vector2.ONE * star_size * (1.3 if big else 1.0)
		_icons[i].texture = Icons.STAR if i < stars else Icons.STAR_OUTLINE
		_icons[i].modulate = gold if i < stars else Color(empty, 0.7)
