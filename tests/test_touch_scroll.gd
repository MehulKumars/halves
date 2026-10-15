extends GutTest
## TouchScrollContainer: a drag that starts on a button scrolls the list and does not press the
## button; a tap still presses it. (A phone test found shop and credits lists hard to scroll.)

var _scroll: TouchScrollContainer
var _buttons: Array[Button] = []


func before_each() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child_autofree(layer)
	_scroll = TouchScrollContainer.new()
	_scroll.position = Vector2.ZERO
	_scroll.size = Vector2(400, 400)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layer.add_child(_scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = 380
	_scroll.add_child(list)
	_buttons.clear()
	for i in 12:
		var button := Button.new()
		button.text = "Pack %d" % i
		button.custom_minimum_size.y = 96
		button.set_meta(&"ui_feedback", false)
		list.add_child(button)
		_buttons.append(button)
	await wait_process_frames(3)


func test_drag_on_a_button_scrolls_without_pressing_it() -> void:
	watch_signals(_buttons[1])
	_press(Vector2(200, 150))
	for y in [140.0, 120.0, 90.0, 60.0, 30.0]:
		_drag_to(Vector2(200, y))
	_release(Vector2(200, 30))
	await wait_process_frames(2)
	assert_gt(_scroll.scroll_vertical, 60, "the list moved with the finger")
	assert_signal_not_emitted(_buttons[1], "pressed", "scrolling must not press the button")


func test_tap_still_presses_the_button() -> void:
	watch_signals(_buttons[1])
	_press(Vector2(200, 150))
	_release(Vector2(200, 150))
	await wait_process_frames(1)
	assert_signal_emitted(_buttons[1], "pressed")
	assert_eq(_scroll.scroll_vertical, 0)


func test_small_wobble_is_still_a_tap() -> void:
	watch_signals(_buttons[1])
	_press(Vector2(200, 150))
	_drag_to(Vector2(204, 156))
	_release(Vector2(204, 156))
	await wait_process_frames(1)
	assert_signal_emitted(_buttons[1], "pressed", "under 7 dp of movement is a tap")


func _press(pos: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = pos
	event.global_position = pos
	get_viewport().push_input(event, true)


func _drag_to(pos: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = pos
	event.global_position = pos
	get_viewport().push_input(event, true)


func _release(pos: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = pos
	event.global_position = pos
	get_viewport().push_input(event, true)
