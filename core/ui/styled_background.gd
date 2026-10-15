@tool
class_name StyledBackground
extends ColorRect
## Full-screen gradient and pattern taken from the current theme's Tokens (see UIStyle).
## Put one at the back of every screen; it follows style changes and the Reduce Motion setting.

const SHADER: Shader = preload("res://core/ui/styled_background.gdshader")

var _material := ShaderMaterial.new()
var _speed: float = 0.0
var _offset: float = 0.0


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_material.shader = SHADER
	material = _material


func _ready() -> void:
	resized.connect(_on_resized)
	_apply()
	_on_resized()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_apply()


## The material and colour come from the theme at run time; never save them into scenes.
func _validate_property(property: Dictionary) -> void:
	if property.name in [&"material", &"color"]:
		property.usage &= ~PROPERTY_USAGE_STORAGE


func _process(delta: float) -> void:
	if _speed == 0.0 or Engine.is_editor_hint():
		return
	_offset = fmod(_offset + _speed * Juice.motion_scale * delta, 100000.0)
	_material.set_shader_parameter(&"offset", _offset)


func _apply() -> void:
	color = get_theme_color(&"bg_bottom", &"Tokens")
	_material.set_shader_parameter(&"top_color", get_theme_color(&"bg_top", &"Tokens"))
	_material.set_shader_parameter(&"bottom_color", get_theme_color(&"bg_bottom", &"Tokens"))
	_material.set_shader_parameter(&"pattern_color", get_theme_color(&"pattern_color", &"Tokens"))
	_material.set_shader_parameter(&"pattern", get_theme_constant(&"pattern", &"Tokens"))
	_material.set_shader_parameter(&"pattern_scale", float(get_theme_constant(&"pattern_scale", &"Tokens")))
	_speed = get_theme_constant(&"pattern_speed", &"Tokens")
	set_process(_speed != 0.0)


func _on_resized() -> void:
	_material.set_shader_parameter(&"rect_size", size)
