extends SceneTree
## Builds one Theme per UIStyle: core/ui/styles/<id>.tres -> core/ui/themes/<id>.tres.
## Run after changing a style, then look at the result with tools/snapshots.ps1:
##   godot --headless --path . -s tools/build_theme.gd
## This file is the design system: it decides how style tokens become buttons, cards, sliders.
## The tokens are also stored in each theme as type "Tokens", so code can read them:
##   get_theme_color(&"accent", &"Tokens"), get_theme_constant(&"touch_target", &"Tokens").
## tests/test_theme.gd checks contrast (WCAG AA) and touch sizes of every built theme.

const STYLES_DIR: String = "res://core/ui/styles/"
const THEMES_DIR: String = "res://core/ui/themes/"

const TOUCH := 96          # minimum touch target in canvas px (48 dp on a 360 dp phone)
const HERO := 128          # height of the big primary button
const CHIP := 96
const GAP := 24
const SCREEN_MARGIN := 40
const FONT_SMALL := 26
const FONT_HEADER := 52
const FONT_SCREEN_HEADER := 48
const FONT_VALUE := 36
const FONT_HERO := 46
const FONT_BADGE := 24

var _s: UIStyle
var _t: Theme
var _body: FontVariation
var _display: FontVariation
var _value: FontVariation


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(THEMES_DIR))
	var failed := 0
	for file in DirAccess.get_files_at(STYLES_DIR):
		if not file.ends_with(".tres"):
			continue
		var style := load(STYLES_DIR + file) as UIStyle
		if style == null:
			printerr("build_theme: %s is not a UIStyle" % file)
			failed += 1
			continue
		var path := THEMES_DIR + String(style.id) + ".tres"
		var theme := build(style)
		var uid := ResourceLoader.get_resource_uid(path) if ResourceLoader.exists(path) else ResourceUID.INVALID_ID
		var err := ResourceSaver.save(theme, path)
		if err == OK and uid != ResourceUID.INVALID_ID:
			err = ResourceSaver.set_uid(path, uid)
		if err != OK:
			printerr("build_theme: saving %s failed: %s" % [path, error_string(err)])
			failed += 1
		else:
			print("build_theme: wrote ", path)
	quit(1 if failed > 0 else 0)


func build(style: UIStyle) -> Theme:
	_s = style
	_value = null
	_t = Theme.new()
	_body = _font("body_font", style.body_font, style.body_weight)
	_display = _font("display_font", style.display_font, style.display_weight)
	_t.default_font = _body
	_t.default_font_size = style.font_size
	_tokens()
	_labels()
	_buttons()
	_panels()
	_controls()
	return _t


# --- Tokens ------------------------------------------------------------------------------

func _tokens() -> void:
	var colors := {
		&"bg_top": _s.bg_top, &"bg_bottom": _s.bg_bottom, &"text_on_bg": _s.text_on_bg,
		&"surface": _s.surface, &"surface_border": _s.surface_border, &"text": _s.text,
		&"text_muted": _s.text_muted, &"raised": _s.raised, &"text_on_raised": _s.text_on_raised,
		&"accent": _s.accent, &"on_accent": _s.on_accent, &"gold": _s.gold, &"positive": _s.positive,
		&"danger": _s.danger, &"scrim": _s.scrim, &"pattern_color": _s.pattern_color,
	}
	for key: StringName in colors:
		_t.set_color(key, &"Tokens", colors[key])
	var constants := {
		&"touch_target": TOUCH, &"hero_height": HERO, &"gap": GAP, &"screen_margin": SCREEN_MARGIN,
		&"radius": _s.radius, &"panel_radius": _s.panel_radius, &"pattern": _s.pattern,
		&"pattern_scale": roundi(_s.pattern_scale), &"pattern_speed": roundi(_s.pattern_speed),
		&"glow": 1 if _s.glow else 0, &"pixel": 1 if _s.button_shape == UIStyle.ButtonShape.PIXEL else 0,
	}
	for key: StringName in constants:
		_t.set_constant(key, &"Tokens", constants[key])
	var sizes := {&"small": _size(FONT_SMALL), &"body": _s.font_size, &"header": FONT_HEADER, &"title": _s.title_size}
	for key: StringName in sizes:
		_t.set_font_size(key, &"Tokens", sizes[key])
	_t.set_font(&"display", &"Tokens", _display)
	_t.set_font(&"body", &"Tokens", _body)


# --- Labels ------------------------------------------------------------------------------

func _labels() -> void:
	_t.set_color(&"font_color", &"Label", _s.text)
	_label(&"OnBgLabel", _body, _s.font_size, _s.text_on_bg, _s.text_outline / 2)
	_label(&"TitleLabel", _display, _s.title_size, _s.text_on_bg, _s.text_outline)
	_label(&"ScreenHeaderLabel", _display, FONT_SCREEN_HEADER, _s.text_on_bg, _s.text_outline / 2)
	_label(&"HeaderLabel", _display, FONT_HEADER, _s.text, 0)
	_label(&"CaptionLabel", _body, _size(FONT_SMALL), _s.text_muted, 0)
	_label(&"ValueLabel", _value_font(), _size(FONT_VALUE), _s.text, 0)
	_label(&"BadgeLabel", _value_font(), _size(FONT_BADGE), _s.on_accent, 0)
	if _s.glow:
		for type: StringName in [&"TitleLabel", &"ScreenHeaderLabel"]:
			_t.set_color(&"font_shadow_color", type, Color(_s.accent, 0.75))
			_t.set_constant(&"shadow_outline_size", type, 14)
			_t.set_constant(&"shadow_offset_x", type, 0)
			_t.set_constant(&"shadow_offset_y", type, 0)
	_t.set_color(&"default_color", &"RichTextLabel", _s.text)
	_t.set_font(&"bold_font", &"RichTextLabel", _display)
	_t.set_font_size(&"bold_font_size", &"RichTextLabel", _s.font_size)


func _label(type: StringName, font: Font, size: int, color: Color, outline: int) -> void:
	_t.set_type_variation(type, &"Label")
	_t.set_font(&"font", type, font)
	_t.set_font_size(&"font_size", type, size)
	_t.set_color(&"font_color", type, color)
	if outline > 0:
		_t.set_constant(&"outline_size", type, outline)
		_t.set_color(&"font_outline_color", type, _s.text_outline_color)


# --- Buttons -----------------------------------------------------------------------------

func _buttons() -> void:
	_button(&"Button", _s.raised, _s.raised_edge, _s.text_on_raised, TOUCH, _body, _s.font_size + 2)
	_button(&"AccentButton", _s.accent, _s.accent_edge, _s.on_accent, TOUCH, _body, _s.font_size + 2)
	_button(&"HeroButton", _s.accent, _s.accent_edge, _s.on_accent, HERO, _display, FONT_HERO)
	_button(&"DangerButton", _s.danger, _s.danger.darkened(0.35), _s.on_danger, TOUCH, _body, _s.font_size + 2)
	_button(&"IconButton", _s.raised, _s.raised_edge, _s.text_on_raised, TOUCH, _body, _s.font_size, true)
	_button(&"AccentIconButton", _s.accent, _s.accent_edge, _s.on_accent, TOUCH, _body, _s.font_size, true)
	_button(&"TileButton", _s.raised, _s.raised_edge, _s.text_on_raised, TOUCH, _value_font(), _size(FONT_VALUE) + 4)
	_button(&"AccentTileButton", _s.accent, _s.accent_edge, _s.on_accent, TOUCH, _value_font(), _size(FONT_VALUE) + 8)
	_ghost_button()
	_chip_button()


## One button type in the style's shape. Every state keeps the same total margins, so a
## pressed button never changes size (a size change would re-sort its container).
func _button(type: StringName, face: Color, line: Color, text: Color, height: int, font: Font, size: int, square: bool = false) -> void:
	if type != &"Button":
		_t.set_type_variation(type, &"Button")
	var name := String(type).to_snake_case()
	var line_h := _line_height(font, size)
	var styles := _button_boxes(name, face, line, height, line_h, square)
	for state: StringName in styles:
		_t.set_stylebox(state, type, styles[state])
	_t.set_stylebox(&"focus", type, _focus_ring(name + "_focus"))
	_t.set_font(&"font", type, font)
	_t.set_font_size(&"font_size", type, size)
	# Outline buttons are dark with coloured text, and fill with the colour when pressed.
	var pressed_text := text
	if _s.button_shape == UIStyle.ButtonShape.OUTLINE:
		if face != _s.raised:
			text = face.lightened(0.2)
		pressed_text = _s.on_accent
	for state: StringName in [&"font_color", &"font_hover_color", &"font_focus_color", &"icon_normal_color", &"icon_hover_color", &"icon_focus_color"]:
		_t.set_color(state, type, text)
	for state: StringName in [&"font_pressed_color", &"font_hover_pressed_color", &"icon_pressed_color", &"icon_hover_pressed_color"]:
		_t.set_color(state, type, pressed_text)
	_t.set_color(&"font_disabled_color", type, Color(text, 0.5))
	_t.set_color(&"icon_disabled_color", type, Color(text, 0.5))
	_t.set_constant(&"icon_max_width", type, 48)
	_t.set_constant(&"h_separation", type, 14)
	var outline := _text_outline_for(line, text)
	if outline.x > 0:
		_t.set_constant(&"outline_size", type, int(outline.x))
		_t.set_color(&"font_outline_color", type, Color(outline.y, outline.z, outline.w))
	else:
		# Variations fall back to Button, so switch an inherited outline off explicitly.
		_t.set_constant(&"outline_size", type, 0)


## x = outline size, yzw = outline colour (rgb). Outlined styles darken the button edge colour.
## Dark text gets no outline: a dark outline on dark text only makes it look smudged.
func _text_outline_for(line: Color, text: Color) -> Vector4:
	if _s.text_outline <= 0 or text.get_luminance() < 0.4:
		return Vector4.ZERO
	var color := _s.text_outline_color if _s.button_shape == UIStyle.ButtonShape.PIXEL else line.darkened(0.45)
	return Vector4(_s.text_outline * 0.75, color.r, color.g, color.b)


func _button_boxes(name: String, face: Color, line: Color, height: int, line_h: float, square: bool) -> Dictionary:
	var shape := _s.button_shape
	var edge := _s.edge_depth if shape in [UIStyle.ButtonShape.CHUNKY, UIStyle.ButtonShape.PIXEL] else 0
	var side := _s.border_width if shape != UIStyle.ButtonShape.FLAT else 0
	if shape == UIStyle.ButtonShape.CHUNKY and _s.border_width <= 2:
		side = 0
	var bottom := maxi(edge, side)
	var v_total := float(height) - line_h
	var h_margin := (height - 48) / 2.0 if square else 36.0
	var up := _box(name + "_normal", face, _s.radius)
	up.border_color = line
	up.border_width_left = side
	up.border_width_right = side
	up.border_width_top = side
	up.border_width_bottom = bottom
	up.content_margin_left = h_margin
	up.content_margin_right = h_margin
	up.content_margin_top = (v_total - bottom + side) / 2.0
	up.content_margin_bottom = (v_total + bottom - side) / 2.0
	if square:
		up.content_margin_top = (height - 48 - bottom + side) / 2.0
		up.content_margin_bottom = (height - 48 + bottom - side) / 2.0
	var over := _copy(up, name + "_hover")
	var down := _copy(up, name + "_pressed")
	var off := _copy(up, name + "_disabled")
	match shape:
		UIStyle.ButtonShape.FLAT:
			over.bg_color = face.lightened(0.08)
			down.bg_color = face.darkened(0.14)
		UIStyle.ButtonShape.CHUNKY, UIStyle.ButtonShape.PIXEL:
			over.bg_color = face.lightened(0.06)
			down.bg_color = face.darkened(0.06)
			var sink := float(bottom - side)
			down.border_width_bottom = side
			down.expand_margin_top = -sink
			down.content_margin_top = up.content_margin_top + sink
			down.content_margin_bottom = up.content_margin_bottom - sink
		UIStyle.ButtonShape.OUTLINE:
			up.bg_color = _s.bg_bottom.lerp(face, 0.16) if face != _s.raised else _s.raised
			up.border_color = face if face != _s.raised else line
			up.shadow_color = Color(up.border_color, 0.45)
			up.shadow_size = 12
			over.bg_color = _s.bg_bottom.lerp(up.border_color, 0.3)
			over.border_color = up.border_color
			over.shadow_color = up.shadow_color
			over.shadow_size = 18
			down.bg_color = up.border_color
			down.border_color = up.border_color
			down.shadow_color = Color(up.border_color, 0.7)
			down.shadow_size = 22
	off.bg_color = Color(up.bg_color, up.bg_color.a * 0.4)
	off.border_color = Color(up.border_color, 0.4)
	off.shadow_size = 0
	return {&"normal": up, &"hover": over, &"pressed": down, &"hover_pressed": down, &"disabled": off}


func _ghost_button() -> void:
	_t.set_type_variation(&"GhostButton", &"Button")
	var box := StyleBoxEmpty.new()
	box.resource_scene_unique_id = "ghost_button"
	box.content_margin_left = 24
	box.content_margin_right = 24
	box.content_margin_top = (TOUCH - _line_height(_body, _s.font_size)) / 2.0
	box.content_margin_bottom = box.content_margin_top
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		_t.set_stylebox(state, &"GhostButton", box)
	_t.set_stylebox(&"focus", &"GhostButton", _focus_ring("ghost_button_focus"))
	for state: StringName in [&"font_color", &"font_focus_color", &"icon_normal_color", &"icon_focus_color"]:
		_t.set_color(state, &"GhostButton", _s.text_muted)
	for state: StringName in [&"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color", &"icon_hover_color", &"icon_pressed_color"]:
		_t.set_color(state, &"GhostButton", _s.text)
	_t.set_constant(&"outline_size", &"GhostButton", 0)


## Toggle chips (style picker, segmented choices): raised when off, accent when on.
func _chip_button() -> void:
	_t.set_type_variation(&"ChipButton", &"Button")
	var off := _box("chip_off", _s.raised, _s.radius)
	off.set_border_width_all(maxi(2, _s.border_width / 2))
	off.border_color = _s.raised_edge
	var on := _box("chip_on", _s.accent, _s.radius)
	on.set_border_width_all(maxi(2, _s.border_width / 2))
	on.border_color = _s.accent_edge
	for box: StyleBoxFlat in [off, on]:
		box.content_margin_left = 28
		box.content_margin_right = 28
		box.content_margin_top = (CHIP - _line_height(_body, _s.font_size)) / 2.0
		box.content_margin_bottom = box.content_margin_top
	for state: StringName in [&"normal", &"hover", &"disabled"]:
		_t.set_stylebox(state, &"ChipButton", off)
	for state: StringName in [&"pressed", &"hover_pressed"]:
		_t.set_stylebox(state, &"ChipButton", on)
	for state: StringName in [&"font_color", &"font_hover_color", &"font_focus_color"]:
		_t.set_color(state, &"ChipButton", _s.text_on_raised)
	for state: StringName in [&"font_pressed_color", &"font_hover_pressed_color"]:
		_t.set_color(state, &"ChipButton", _s.on_accent)
	_t.set_constant(&"outline_size", &"ChipButton", 0)


# --- Panels ------------------------------------------------------------------------------

func _panels() -> void:
	var card := _card("card", 32)
	_t.set_stylebox(&"panel", &"PanelContainer", card)
	_t.set_stylebox(&"panel", &"Panel", card)
	_panel_variation(&"SheetPanel", _card("sheet", 40))
	_panel_variation(&"TilePanel", _card("tile", 24))
	var highlight := _card("highlight", 24)
	highlight.border_color = _s.accent
	highlight.set_border_width_all(maxi(4, _s.border_width))
	_panel_variation(&"HighlightPanel", highlight)
	var pill := _box("pill", _s.surface, 999 if _s.anti_aliasing else 0)
	pill.set_border_width_all(maxi(2, _s.border_width / 2))
	pill.border_color = _s.surface_border
	pill.content_margin_left = 14
	pill.content_margin_right = 22
	pill.content_margin_top = 6
	pill.content_margin_bottom = 6
	_panel_variation(&"PillPanel", pill)
	var badge := _box("badge", _s.accent, 999 if _s.anti_aliasing else 0)
	badge.content_margin_left = 16
	badge.content_margin_right = 16
	badge.content_margin_top = 2
	badge.content_margin_bottom = 2
	_panel_variation(&"BadgePanel", badge)
	var dot := _box("dot", _s.danger, 999 if _s.anti_aliasing else 0)
	dot.set_border_width_all(3)
	dot.border_color = _s.surface
	_panel_variation(&"DotPanel", dot)
	var bar := StyleBoxEmpty.new()
	bar.resource_scene_unique_id = "bar"
	_panel_variation(&"BarPanel", bar)
	var toast := _card("toast", 0)
	toast.content_margin_left = 32
	toast.content_margin_right = 32
	toast.content_margin_top = 20
	toast.content_margin_bottom = 20
	_panel_variation(&"ToastPanel", toast)
	var line := StyleBoxLine.new()
	line.resource_scene_unique_id = "separator"
	line.color = _s.surface_border
	line.thickness = 2
	_t.set_stylebox(&"separator", &"HSeparator", line)
	_t.set_constant(&"separation", &"HSeparator", GAP)


func _card(id: String, margin: int) -> StyleBoxFlat:
	var box := _box(id, _s.surface, _s.panel_radius)
	box.set_border_width_all(_s.border_width)
	box.border_color = _s.surface_border
	box.shadow_size = _s.shadow_size
	box.shadow_offset = _s.shadow_offset
	box.shadow_color = _s.shadow_color
	box.set_content_margin_all(margin)
	return box


func _panel_variation(type: StringName, box: StyleBox) -> void:
	_t.set_type_variation(type, &"PanelContainer")
	_t.set_stylebox(&"panel", type, box)


# --- Sliders, toggles, bars ---------------------------------------------------------------

func _controls() -> void:
	_slider()
	_toggle()
	var bg := _box("progress_background", _s.raised, mini(_s.radius, 14))
	bg.content_margin_top = 14
	bg.content_margin_bottom = 14
	bg.border_color = _s.raised_edge
	bg.set_border_width_all(2 if _s.border_width > 0 else 0)
	_t.set_stylebox(&"background", &"ProgressBar", bg)
	_t.set_stylebox(&"fill", &"ProgressBar", _box("progress_fill", _s.accent, mini(_s.radius, 14)))
	_t.set_color(&"font_color", &"ProgressBar", _s.text)
	var lane := StyleBoxEmpty.new()
	lane.resource_scene_unique_id = "scroll_lane"
	lane.content_margin_left = 5
	lane.content_margin_right = 5
	var thumb := _box("scroll_thumb", Color(_s.text_muted, 0.5), 5)
	thumb.content_margin_left = 5
	thumb.content_margin_right = 5
	_t.set_stylebox(&"scroll", &"VScrollBar", lane)
	_t.set_stylebox(&"grabber", &"VScrollBar", thumb)
	_t.set_stylebox(&"grabber_highlight", &"VScrollBar", thumb)
	_t.set_stylebox(&"grabber_pressed", &"VScrollBar", thumb)
	var empty := StyleBoxEmpty.new()
	empty.resource_scene_unique_id = "empty"
	_t.set_stylebox(&"panel", &"ScrollContainer", empty)


## A tall invisible hit area with a thin visible track: content margins make the slider TOUCH
## tall, negative expand margins draw only the middle `track` pixels.
func _slider() -> void:
	var track_h := 14 if _s.button_shape != UIStyle.ButtonShape.PIXEL else 16
	var half := TOUCH / 2.0
	var shrink := -(half - track_h / 2.0)
	var track := _box("slider_track", _track_color(), track_h / 2)
	var filled := _box("slider_fill", _s.accent, track_h / 2)
	for box: StyleBoxFlat in [track, filled]:
		box.content_margin_top = half
		box.content_margin_bottom = half
		box.expand_margin_top = shrink
		box.expand_margin_bottom = shrink
	_t.set_stylebox(&"slider", &"HSlider", track)
	_t.set_stylebox(&"grabber_area", &"HSlider", filled)
	_t.set_stylebox(&"grabber_area_highlight", &"HSlider", filled)
	var knob_fill: Color = _s.on_accent if _s.button_shape == UIStyle.ButtonShape.OUTLINE else Color.WHITE
	var svg: String
	if _s.button_shape == UIStyle.ButtonShape.PIXEL:
		svg = '<svg xmlns="http://www.w3.org/2000/svg" width="44" height="44" shape-rendering="crispEdges"><rect x="4" y="4" width="36" height="36" fill="#%s"/><rect x="10" y="10" width="24" height="24" fill="#%s"/></svg>' % [_hex(_s.raised_edge), _hex(_s.text)]
	else:
		svg = '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48"><circle cx="24" cy="24" r="19" fill="#%s" stroke="#%s" stroke-width="5"/></svg>' % [_hex(knob_fill), _hex(_s.accent)]
	var knob := _svg("slider_knob", svg)
	_t.set_icon(&"grabber", &"HSlider", knob)
	_t.set_icon(&"grabber_highlight", &"HSlider", knob)
	_t.set_icon(&"grabber_disabled", &"HSlider", knob)
	_t.set_icon(&"tick", &"HSlider", _svg("slider_tick", '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"/>'))


## Switch icons. Off: outlined track with a small knob. On: accent track with a large knob.
## The state is shown by knob size and position, not by colour alone.
func _toggle() -> void:
	var pixel := _s.button_shape == UIStyle.ButtonShape.PIXEL
	var on_track := _hex(_s.accent)
	var on_knob := _hex(_s.on_accent)
	var off_fill := _hex(_track_color())
	var off_line := _hex(_s.text_muted)
	var crisp := ' shape-rendering="crispEdges"' if pixel else ""
	var parts := {}
	if pixel:
		parts = {
			"on": '<rect x="2" y="6" width="92" height="40" fill="#%s"/><rect x="54" y="10" width="32" height="32" fill="#%s"/>' % [on_track, on_knob],
			"off": '<rect x="4" y="8" width="88" height="36" fill="#%s" stroke="#%s" stroke-width="4"/><rect x="12" y="16" width="20" height="20" fill="#%s"/>' % [off_fill, off_line, off_line],
			"on_m": '<rect x="2" y="6" width="92" height="40" fill="#%s"/><rect x="10" y="10" width="32" height="32" fill="#%s"/>' % [on_track, on_knob],
			"off_m": '<rect x="4" y="8" width="88" height="36" fill="#%s" stroke="#%s" stroke-width="4"/><rect x="64" y="16" width="20" height="20" fill="#%s"/>' % [off_fill, off_line, off_line],
		}
	else:
		parts = {
			"on": '<rect x="2" y="4" width="92" height="44" rx="22" fill="#%s"/><circle cx="70" cy="26" r="17" fill="#%s"/>' % [on_track, on_knob],
			"off": '<rect x="3.5" y="5.5" width="89" height="41" rx="20.5" fill="#%s" stroke="#%s" stroke-width="3"/><circle cx="26" cy="26" r="11" fill="#%s"/>' % [off_fill, off_line, off_line],
			"on_m": '<rect x="2" y="4" width="92" height="44" rx="22" fill="#%s"/><circle cx="26" cy="26" r="17" fill="#%s"/>' % [on_track, on_knob],
			"off_m": '<rect x="3.5" y="5.5" width="89" height="41" rx="20.5" fill="#%s" stroke="#%s" stroke-width="3"/><circle cx="70" cy="26" r="11" fill="#%s"/>' % [off_fill, off_line, off_line],
		}
	var wrap := '<svg xmlns="http://www.w3.org/2000/svg" width="96" height="52"%s><g opacity="%s">%s</g></svg>'
	var icons := {
		&"checked": ["on", "1"], &"unchecked": ["off", "1"],
		&"checked_disabled": ["on", "0.4"], &"unchecked_disabled": ["off", "0.4"],
		&"checked_mirrored": ["on_m", "1"], &"unchecked_mirrored": ["off_m", "1"],
		&"checked_disabled_mirrored": ["on_m", "0.4"], &"unchecked_disabled_mirrored": ["off_m", "0.4"],
	}
	for key: StringName in icons:
		var spec: Array = icons[key]
		_t.set_icon(key, &"CheckButton", _svg("toggle_" + key, wrap % [crisp, spec[1], parts[spec[0]]]))
	var row := StyleBoxEmpty.new()
	row.resource_scene_unique_id = "toggle_row"
	row.content_margin_left = 4
	row.content_margin_right = 4
	row.content_margin_top = (TOUCH - 52) / 2.0
	row.content_margin_bottom = (TOUCH - 52) / 2.0
	for state: StringName in [&"normal", &"pressed", &"hover", &"hover_pressed", &"disabled"]:
		_t.set_stylebox(state, &"CheckButton", row)
	_t.set_stylebox(&"focus", &"CheckButton", _focus_ring("toggle_focus"))
	_t.set_constant(&"h_separation", &"CheckButton", 16)
	# CheckButton falls back to Button items; without this the switch is capped at 48 px wide.
	_t.set_constant(&"icon_max_width", &"CheckButton", 0)
	for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color", &"font_focus_color"]:
		_t.set_color(state, &"CheckButton", _s.text)


# --- Helpers -----------------------------------------------------------------------------

func _focus_ring(id: String) -> StyleBoxFlat:
	var ring := _box(id, Color.TRANSPARENT, _s.radius + 6 if _s.radius > 0 else 0)
	ring.draw_center = false
	ring.set_border_width_all(4)
	ring.border_color = _s.accent if _s.accent.get_luminance() > 0.2 else _s.text_on_bg
	ring.set_expand_margin_all(7)
	return ring


func _box(id: String, color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.resource_scene_unique_id = id
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.anti_aliasing = _s.anti_aliasing
	box.corner_detail = 10 if _s.anti_aliasing else 1
	return box


func _copy(box: StyleBoxFlat, id: String) -> StyleBoxFlat:
	var copy := box.duplicate() as StyleBoxFlat
	copy.resource_scene_unique_id = id
	return copy


func _font(id: String, base: Font, weight: int) -> FontVariation:
	var font := FontVariation.new()
	font.resource_scene_unique_id = id
	font.base_font = base
	var ts := TextServerManager.get_primary_interface()
	font.variation_opentype = {ts.name_to_tag("wght"): weight}
	return font


func _svg(id: String, source: String) -> DPITexture:
	var texture := DPITexture.create_from_string(source)
	texture.resource_scene_unique_id = id
	return texture


func _hex(color: Color) -> String:
	return color.to_html(false)


func _line_height(font: Font, size: int) -> float:
	return font.get_height(size)


## Numbers (coins, scores) use the body font at the display weight: some display fonts,
## such as Orbitron, draw a slashed zero that reads like a "no" sign.
func _value_font() -> FontVariation:
	if _value == null or _value.base_font != _s.body_font:
		_value = _font("value_font", _s.body_font, _s.display_weight)
	return _value


## Unfilled slider and switch tracks: the card colour pulled towards the muted text, so they
## read on light and dark cards alike.
func _track_color() -> Color:
	return _s.surface.lerp(_s.text_muted, 0.35)


## Sizes for text drawn in the body font (captions, numbers), scaled for fonts that run small.
func _size(base: int) -> int:
	return roundi(base * _s.text_scale)
