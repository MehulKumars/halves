extends Screen
## First screen after launch: the game's name on the style's background for about a second,
## then the main menu (tap to skip). Counts the launch for AdPolicy's ad-free first session.
## A brand-new player goes straight into level 1 instead (Halves teaches by playing, no menus).

const HOLD_SECONDS: float = 1.1

var _leaving: bool = false


func _ready() -> void:
	Progress.start_session()
	%Title.text = ProjectSettings.get_setting("application/config/name", "Mobile Game")
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = HOLD_SECONDS
	timer.timeout.connect(_continue)
	add_child(timer)
	timer.start()
	if Juice.motion_scale > 0.0:
		var logo: Control = %Logo
		logo.modulate.a = 0.0
		logo.pivot_offset_ratio = Vector2(0.5, 0.5)
		logo.scale = Vector2.ONE * 0.92
		var tween := create_tween().set_parallel()
		tween.tween_property(logo, ^"modulate:a", 1.0, 0.35)
		tween.tween_property(logo, ^"scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.is_pressed():
		_continue()


func on_back() -> void:
	_continue()


func _continue() -> void:
	if _leaving:
		return
	_leaving = true
	if Progress.levels_won() == 0:
		Screens.level = 1
		UI.goto(Screens.GAME)
	else:
		UI.goto(Screens.MAIN_MENU)
