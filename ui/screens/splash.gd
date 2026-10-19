extends Screen
## First screen after launch: over the current chapter's print, two half tiles slide in and snap
## into the Halves mark with a burst, the name rises in, then the main menu (tap to skip). Counts
## the launch for AdPolicy. A brand-new player goes straight into level 1 (Halves teaches by playing).

const HOLD_SECONDS: float = 1.0

var _leaving: bool = false
var _mark: HalvesLogo
var _shards: HalvesShardPool


func _ready() -> void:
	Progress.start_session()
	var chapter := HalvesChapters.index_for_level(Progress.next_level())
	ChapterBackground.install(self, chapter, false)
	%Title.text = ProjectSettings.get_setting("application/config/name", "Halves")
	(%Logo.get_node(^"MadeWith") as Label).text = "a calm puzzle of mirror halves"
	_mark = HalvesLogo.new()
	_mark.custom_minimum_size = Vector2(320, 240)
	_mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var logo: Control = %Logo
	logo.add_child(_mark)
	logo.move_child(_mark, 0)
	_shards = HalvesShardPool.new()
	add_child(_shards)
	_mark.snapped.connect(_on_snapped)
	_play_intro.call_deferred()


func _play_intro() -> void:
	var logo: Control = %Logo
	var title: Control = %Title
	var tagline: Control = %Logo.get_node(^"MadeWith")
	if Juice.motion_scale > 0.0:
		title.modulate.a = 0.0
		tagline.modulate.a = 0.0
	await _mark.snap(0.9)
	if not is_inside_tree():
		return
	if Juice.motion_scale > 0.0:
		var tween := create_tween()
		tween.tween_property(title, ^"modulate:a", 1.0, 0.3)
		tween.parallel().tween_property(title, ^"position:y", title.position.y, 0.4).from(title.position.y + 24.0) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(tagline, ^"modulate:a", 1.0, 0.3)
	await get_tree().create_timer(HOLD_SECONDS).timeout
	if logo.is_inside_tree():
		_continue()


func _on_snapped() -> void:
	HalvesSfx.play(&"snap_big")
	Haptics.pulse(20)
	_shards.burst(_mark.get_global_rect().get_center(), HalvesPalette.COBALT, 2.2, 2.0)


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
		Screens.mode = Screens.Mode.LEVELS
		Screens.level = 1
		UI.goto(Screens.GAME)
	else:
		UI.goto(Screens.MAIN_MENU)
