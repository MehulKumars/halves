@tool
class_name AdaptiveGridContainer
extends GridContainer
## A grid that picks its column count from its width: 4 level tiles on a phone, 6 on a
## tablet. Cells are at least `min_cell_width` wide; set size_flags_horizontal = FILL on
## children so they share the extra space.

@export var min_cell_width: float = 140.0:
	set(value):
		min_cell_width = value
		_update_columns()
@export_range(1, 12) var min_columns: int = 2:
	set(value):
		min_columns = value
		_update_columns()
@export_range(1, 12) var max_columns: int = 6:
	set(value):
		max_columns = value
		_update_columns()


func _ready() -> void:
	resized.connect(_update_columns)
	_update_columns()


## Columns that fit `width` with cells of at least `cell` and `gap` between them.
static func columns_for(width: float, cell: float, gap: float, lowest: int, highest: int) -> int:
	if width <= 0.0 or cell <= 0.0:
		return lowest
	return clampi(floori((width + gap) / (cell + gap)), lowest, highest)


func _update_columns() -> void:
	if not is_inside_tree():
		return
	var gap := float(get_theme_constant(&"h_separation"))
	var wanted := columns_for(size.x, min_cell_width, gap, min_columns, max_columns)
	if wanted != columns:
		columns = wanted
