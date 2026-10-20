extends Modal
## A rule card with a tiny board drawn by the real tile art (HalvesTips). setup(id) shows one tip
## and marks it seen; setup_all() pages through every rule ("How to play" in the pause menu).
## Closes with null. Opened by the game screen before play on the level that brings a rule in.

var _ids: Array = []
var _page: int = 0
var _title: Label
var _board: HalvesBoardView
var _text: Label
var _next: Button
var _back: Button
var _counter: Label


func _ready() -> void:
	super._ready()
	var content: VBoxContainer = %Content
	_title = Label.new()
	_title.theme_type_variation = &"HeaderLabel"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_title)
	_board = HalvesBoardView.new()
	_board.custom_minimum_size = Vector2(540, 200)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_board)
	_text = Label.new()
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(480, 0)
	content.add_child(_text)
	_counter = Label.new()
	_counter.theme_type_variation = &"CaptionLabel"
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_counter)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	content.add_child(row)
	_back = Button.new()
	_back.text = "Back"
	_back.theme_type_variation = &"GhostButton"
	_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_back.pressed.connect(func() -> void: _show(_page - 1))
	row.add_child(_back)
	_next = Button.new()
	_next.theme_type_variation = &"AccentButton"
	_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next.pressed.connect(_on_next)
	row.add_child(_next)


func setup(id: String) -> void:
	_ids = [id]
	_show(0)


func setup_all() -> void:
	_ids = HalvesTips.ids()
	_show(0)


func _on_next() -> void:
	if _page + 1 < _ids.size():
		_show(_page + 1)
	else:
		close()


func _show(page: int) -> void:
	_page = clampi(page, 0, _ids.size() - 1)
	var id: String = _ids[_page]
	var tip := HalvesTips.get_tip(id)
	_title.text = str(tip.get("title", ""))
	_text.text = str(tip.get("text", ""))
	var data := HalvesTips.level_data(id)
	_board.setup(data, data.new_state())
	var rings: Dictionary = tip.get("rings", {})
	for tile: int in rings:
		match str(rings[tile]):
			"selected":
				_board.tile_view(tile).set_lifted(true, _board.face_width() * 0.1)
				_board.tile_view(tile).ring = HalvesTileView.Ring.SELECTED
			"mistake":
				_board.tile_view(tile).ring = HalvesTileView.Ring.MISTAKE
			_:
				_board.tile_view(tile).pulse_ring(HalvesTileView.Ring.HINT)
	var paging := _ids.size() > 1
	_back.visible = paging
	_back.disabled = _page == 0
	_counter.visible = paging
	_counter.text = "%d / %d" % [_page + 1, _ids.size()]
	_next.text = "Next" if _page + 1 < _ids.size() else "Got it"
	HalvesRecords.mark_tip(id)
	refit()
