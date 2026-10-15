class_name Modal
extends Control
## Base for popups opened with UI.open(): dims the screen and pops a sheet in from the centre.
## Used by pause, results, settings, daily reward and confirm dialogs. The scene root is a
## full-screen Modal; its content panel must be named "Sheet" with unique name (%Sheet).
## Back (ui_cancel) and tapping the dim backdrop close it when `dismissible`.
## Await the result: `var result = await UI.open(scene).closed`.

signal closed(result: Variant)

## Back and backdrop taps close the popup. Turn off for choices the player must make.
@export var dismissible: bool = true
## Pauses the game while open (pause menu, results).
@export var pauses_game: bool = false
## Widest the sheet gets on tablets; on phones it uses the screen width minus margins.
@export var sheet_max_width: float = 640.0

var is_closing: bool = false
var _scrim := ColorRect.new()
var _was_paused: bool = false
var _pause_restored: bool = false


func _init() -> void:
	# The backdrop is the first child, behind the sheet; added here so it is always freed.
	add_child(_scrim)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim.color = get_theme_color(&"scrim", &"Tokens")
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.gui_input.connect(_on_scrim_input)
	move_child(_scrim, 0)
	get_viewport().size_changed.connect(_fit_sheet)
	_fit_sheet()
	if pauses_game:
		_was_paused = get_tree().paused
		get_tree().paused = true
	_animate(true)


## The content panel. Every Modal scene has a node with unique name "Sheet".
func get_sheet() -> Control:
	return get_node(^"%Sheet") as Control


## Closes with an optional result for whoever awaits `closed`.
func close(result: Variant = null) -> void:
	if is_closing:
		return
	is_closing = true
	await _animate(false)
	_restore_pause()
	closed.emit(result)
	queue_free()


## However the popup leaves (closed, freed by UI.close_all, scene change), unpause what it paused.
func _exit_tree() -> void:
	_restore_pause()


func _restore_pause() -> void:
	if pauses_game and is_inside_tree() and not _pause_restored:
		_pause_restored = true
		get_tree().paused = _was_paused


## Sheet width: the screen minus margins, capped at sheet_max_width. If the sheet has a
## ScrollContainer named %Scroll, it gets the content's height but never more than fits.
func _fit_sheet() -> void:
	var view := get_viewport_rect().size
	var margin := 2.0 * get_theme_constant(&"screen_margin", &"Tokens")
	var sheet := get_sheet()
	sheet.custom_minimum_size.x = minf(view.x - margin, sheet_max_width)
	var scroll := get_node_or_null(^"%Scroll") as ScrollContainer
	if scroll == null or scroll.get_child_count() == 0:
		return
	var content := scroll.get_child(0) as Control
	var insets := SafeAreaMargin.get_insets(get_viewport())
	var others := sheet.get_combined_minimum_size().y - scroll.custom_minimum_size.y
	var room := view.y - insets.y - insets.w - margin - others
	scroll.custom_minimum_size.y = clampf(content.get_combined_minimum_size().y, 0.0, maxf(room, 200.0))


## Call after adding content in code, so the sheet and its %Scroll are sized again.
func refit() -> void:
	_fit_sheet.call_deferred()


func _animate(opening: bool) -> void:
	var sheet := get_sheet()
	sheet.pivot_offset_ratio = Vector2(0.5, 0.5)
	var motion := Juice.motion_scale
	var from_scale := Vector2.ONE * (1.0 - 0.08 * motion)
	var tween := create_tween().set_parallel()
	if opening:
		modulate.a = 0.0
		sheet.scale = from_scale
		tween.tween_property(self, ^"modulate:a", 1.0, 0.16)
		tween.tween_property(sheet, ^"scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(self, ^"modulate:a", 0.0, 0.12)
		tween.tween_property(sheet, ^"scale", from_scale, 0.12)
	await tween.finished


func _on_scrim_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	var click := event as InputEventMouseButton
	var tapped := (touch != null and touch.pressed) or (click != null and click.pressed)
	if tapped and dismissible:
		accept_event()
		close()
