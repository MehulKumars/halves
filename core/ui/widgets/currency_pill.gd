@tool
class_name CurrencyPill
extends PanelContainer
## A rounded counter with an icon, for coins, gems, lives or stars ("PillPanel" style).
## set_value() counts up or down smoothly, so rewards feel earned.

@export var icon: Texture2D = Icons.COIN:
	set(value):
		icon = value
		_refresh()
## Theme Tokens colour for the icon: gold, accent, danger, positive...
@export var icon_token: StringName = &"gold":
	set(value):
		icon_token = value
		_refresh()
@export var value: int = 0:
	set(new_value):
		value = new_value
		_shown = new_value
		_refresh()

var _shown: float = 0.0
var _icon := TextureRect.new()
var _label := Label.new()


## Children are made here, not in _ready, so they are freed with the pill even if it never
## enters the tree (the editor and the exporter create and free scenes that way).
func _init() -> void:
	theme_type_variation = &"PillPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_icon.custom_minimum_size = Vector2(48, 48)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_icon)
	_label.theme_type_variation = &"ValueLabel"
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_label)


func _ready() -> void:
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_refresh()


## Animates the number to `target` (instant when Reduce Motion is on).
func set_value(target: int, seconds: float = 0.6) -> void:
	var from := _shown
	value = target
	if Juice.motion_scale <= 0.0 or not is_inside_tree() or from == float(target):
		return
	_show_number(from)
	var tween := create_tween()
	tween.tween_method(_show_number, from, float(target), seconds).set_ease(Tween.EASE_OUT)
	pivot_offset_ratio = Vector2(0.5, 0.5)
	Juice.pop(self, 1.08, 0.2)


func _show_number(number: float) -> void:
	_shown = number
	_label.text = format_number(roundi(number))


func _refresh() -> void:
	if not is_node_ready():
		return
	_icon.texture = icon
	_icon.modulate = get_theme_color(icon_token, &"Tokens")
	_label.text = format_number(roundi(_shown))


## 12345 -> "12,345".
static func format_number(number: int) -> String:
	var text := str(absi(number))
	var out := ""
	while text.length() > 3:
		out = "," + text.right(3) + out
		text = text.left(text.length() - 3)
	return ("-" if number < 0 else "") + text + out
