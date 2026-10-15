class_name TouchScrollContainer
extends ScrollContainer
## A ScrollContainer that scrolls when you drag anywhere on it, including on buttons and text.
## Godot's own touch scrolling only starts where no control takes the press, so lists made of
## buttons (shop, level select) and text (credits) felt stuck on phones. Once a press moves
## past DRAG_START it becomes a scroll: the button under the finger is released without firing,
## so scrolling never buys or opens anything. A flick keeps gliding. Use it for every list.

## Distance in canvas pixels (7 dp) a press must travel before it counts as a scroll.
const DRAG_START: float = 14.0
## How fast a flick slows down (higher stops sooner).
const FRICTION: float = 5.0

var _tracking: bool = false
var _dragging: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _last_pos: Vector2 = Vector2.ZERO
var _last_time: int = 0
var _velocity: float = 0.0
var _scroll: float = 0.0


func _ready() -> void:
	set_process(false)


func _input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_begin(button.position)
		else:
			_end()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _tracking:
		_move(motion.position)


func _process(delta: float) -> void:
	_scroll -= _velocity * delta
	scroll_vertical = roundi(_scroll)
	_velocity *= exp(-FRICTION * delta)
	var bar := get_v_scroll_bar()
	var at_edge := scroll_vertical <= 0 or scroll_vertical >= int(bar.max_value - bar.page)
	if absf(_velocity) < 15.0 or at_edge:
		set_process(false)


## True while a press on this list has turned into a scroll.
func is_dragging() -> bool:
	return _dragging


func _begin(pos: Vector2) -> void:
	set_process(false)
	_tracking = is_visible_in_tree() and get_global_rect().has_point(pos) and _is_on_top()
	_dragging = false
	_press_pos = pos
	_last_pos = pos
	_last_time = Time.get_ticks_usec()
	_velocity = 0.0
	_scroll = scroll_vertical


func _move(pos: Vector2) -> void:
	if not _dragging:
		var moved := pos - _press_pos
		if absf(moved.y) < DRAG_START or absf(moved.y) < absf(moved.x):
			return
		_dragging = true
		_cancel_press()
		_last_pos = pos
	var now := Time.get_ticks_usec()
	var dy := pos.y - _last_pos.y
	var seconds := maxf((now - _last_time) / 1_000_000.0, 0.001)
	_velocity = lerpf(_velocity, dy / seconds, 0.5)
	_scroll = clampf(_scroll - dy, 0.0, maxf(get_v_scroll_bar().max_value - get_v_scroll_bar().page, 0.0))
	scroll_vertical = roundi(_scroll)
	_last_pos = pos
	_last_time = now
	# Nothing else (the button, Godot's own scrolling) sees the drag.
	get_viewport().set_input_as_handled()


func _end() -> void:
	if not _tracking:
		return
	_tracking = false
	if _dragging:
		_dragging = false
		# The release still reaches the button so it lets go of the pointer; it no longer fires.
		if Time.get_ticks_usec() - _last_time > 80_000:
			_velocity = 0.0
		set_process(absf(_velocity) > 60.0)


## Releases the button the drag started on without firing it.
func _cancel_press() -> void:
	for node in find_children("*", "BaseButton", true, false):
		var pressed := node as BaseButton
		if pressed.disabled or not pressed.is_visible_in_tree() or not pressed.get_global_rect().has_point(_press_pos):
			continue
		# Disabling a button clears its half-finished press; re-enable it at once.
		pressed.disabled = true
		pressed.disabled = false
		pressed.button_up.emit()


## Ignore presses meant for a popup drawn over this list.
func _is_on_top() -> bool:
	var top: Modal = UI.top_modal()
	return top == null or top.is_ancestor_of(self)
