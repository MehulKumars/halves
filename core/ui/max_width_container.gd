@tool
class_name MaxWidthContainer
extends Container
## Centres its children and stops them growing wider than `max_width`.
## Phones use the full width; tablets and foldables get a centred column instead of
## stretched buttons. Children still fill the full height.

@export var max_width: float = 680.0:
	set(value):
		max_width = value
		queue_sort()


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		var width := minf(size.x, max_width)
		var rect := Rect2((size.x - width) / 2.0, 0.0, width, size.y)
		for child in get_children():
			var control := child as Control
			if control != null and control.visible and not control.top_level:
				fit_child_in_rect(control, rect)


func _get_minimum_size() -> Vector2:
	var result := Vector2.ZERO
	for child in get_children():
		var control := child as Control
		if control != null and control.visible and not control.top_level:
			result = result.max(control.get_combined_minimum_size())
	return result
