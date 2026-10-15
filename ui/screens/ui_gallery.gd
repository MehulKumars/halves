extends Screen
## Every UI kit component on one page, with a live style switcher. Open it from Settings in a
## debug build (or UI.goto(Screens.GALLERY)) to compare the five styles on a real phone.
## Snapshots render it too (tools/snapshots.ps1).


func _ready() -> void:
	back_scene = Screens.MAIN_MENU
	%BackButton.pressed.connect(on_back)
	%ToastButton.pressed.connect(UI.toast.bind("+50 coins", Icons.COIN))
	%ConfirmButton.pressed.connect(func() -> void: UI.confirm("Delete save?", "This cannot be undone.", "Delete", true))
	%StarsButton.pressed.connect(func() -> void: %Stars.reveal(3))
	%CoinsButton.pressed.connect(func() -> void: %CoinPill.set_value(%CoinPill.value + 250))
	%HeartPill.icon = Icons.HEART
	%HeartPill.icon_token = &"danger"
	%HeartPill.value = 5
	%CoinPill.value = 1250
	%StarPill.icon = Icons.STAR
	%StarPill.value = 42
	%BadgeIcon.modulate = get_theme_color(&"gold", &"Tokens")
	var group := ButtonGroup.new()
	for id in UI.list_styles():
		var style := load("res://core/ui/styles/%s.tres" % id) as UIStyle
		var chip := Button.new()
		chip.theme_type_variation = &"ChipButton"
		chip.toggle_mode = true
		chip.button_group = group
		chip.text = style.display_name if style != null else String(id)
		chip.button_pressed = id == UI.current_style
		chip.pressed.connect(_switch_style.bind(id))
		%StyleChips.add_child(chip)
	var style_now := load("res://core/ui/styles/%s.tres" % UI.current_style) as UIStyle
	%StyleInfo.text = style_now.description if style_now != null else ""


func _switch_style(id: StringName) -> void:
	if id != UI.current_style:
		UI.apply_style(id)
		get_tree().reload_current_scene()
