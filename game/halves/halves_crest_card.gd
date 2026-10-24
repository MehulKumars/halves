class_name HalvesCrestCard
extends Control
## One slot in the Crest Book: a restored crest whole on an ivory card, or a faint outline of it
## with its level number while it is still to find. Tapping a restored card names the crest.
## Built by ui/screens/crest_book.gd; drawn with HalvesShapes like the tiles.

var pair: int = -1
var level: int = 0
var restored: bool = false

static var _card: StyleBoxFlat


func _init() -> void:
	custom_minimum_size = Vector2(120, 132)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _card == null:
		_card = StyleBoxFlat.new()
		_card.set_corner_radius_all(18)
		_card.anti_aliasing = true


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	_card.bg_color = HalvesPalette.IVORY if restored else Color(1, 1, 1, 0.08)
	draw_style_box(_card, rect)
	if pair < 0:
		return
	var centre := Vector2(size.x * 0.5, size.y * 0.44)
	var extent := minf(size.x, size.y) * 0.3
	if restored:
		HalvesShapes.draw_whole(self, pair, centre, extent, 0.0)
	else:
		_draw_silhouette(centre, extent)
	var font := get_theme_default_font()
	var colour := HalvesPalette.SIDE if restored else Color(1, 1, 1, 0.55)
	draw_string(font, Vector2(0, size.y - 12), str(level), HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, colour)


## A faint white silhouette of the crest, so the page shows what is still to come.
func _draw_silhouette(centre: Vector2, extent: float) -> void:
	var face := pair << 1
	if HalvesFace.is_crest(face):
		var ghost := Color(1, 1, 1, 0.16)
		HalvesCrest.draw(self, pair, -1, centre, extent * HalvesShapes.CREST_SCALE, ghost, Color(1, 1, 1, 0.0))
	else:
		draw_circle(centre, extent * 0.5, Color(1, 1, 1, 0.12), true, -1.0, true)


func _gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press == null or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if not restored:
		UI.toast("Clear level %d to restore this crest" % level, Icons.LOCK)
		return
	UI.toast(crest_name(pair), Icons.STAR)


## A crest's name ("Cherry blossom"), or the shape's for the first place.
static func crest_name(crest_pair: int) -> String:
	var motif := HalvesCrests.motif_of(crest_pair)
	if motif >= 0:
		return str(HalvesCrests.MOTIFS[motif].name)
	var shape := HalvesFace.shape(crest_pair << 1)
	return ["Circle", "Triangle", "Square", "Diamond"][clampi(shape, 0, 3)]
