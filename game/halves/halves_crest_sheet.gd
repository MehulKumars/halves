class_name HalvesCrestSheet
extends Control
## A debug sheet of crests for judging the art: each motif whole and as its two halves on
## tile-sized faces (96 px wide, as on a phone), 16 motifs a page. Used by tools/snapshots.gd.
## Not part of the game flow; the faces are drawn here, not with HalvesTileView.

const PER_PAGE: int = 16
const FACE := Vector2(96, 110)

## Which page the next sheet shows (0-based), and which cut its halves use.
static var page: int = 0
static var cut: int = HalvesFace.Cut.VERTICAL


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	var area := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, area), Color("#22364F"))
	var font := get_theme_default_font()
	var first := page * PER_PAGE
	var column_w := area.x * 0.5
	var row_h := 172.0
	for i in range(first, mini(first + PER_PAGE, HalvesCrests.motif_count())):
		var slot := i - first
		var origin := Vector2(column_w * (slot % 2) + 14.0, 46.0 + row_h * (slot / 2))
		var pair := HalvesCrests.pair_of(i, cut)
		if not HalvesCrests.is_valid_pair(pair):
			pair = HalvesCrests.pair_of(i, 1 - cut)
		var motif: Dictionary = HalvesCrests.MOTIFS[i]
		var ink := HalvesPalette.family_color(motif.family)
		_card(origin, Vector2(118, 118))
		HalvesCrest.draw(self, pair, -1, origin + Vector2(59, 59), 50.0, ink, HalvesPalette.IVORY)
		for side in 2:
			var at := origin + Vector2(128 + side * (FACE.x + 8.0), 4.0)
			_card(at, FACE)
			var face := pair << 1 | side
			HalvesShapes.draw_half(self, face, at + FACE * 0.5, FACE.x * 0.31)
		draw_string(font, origin + Vector2(0, 140), "%d %s" % [i, motif.id], HORIZONTAL_ALIGNMENT_LEFT,
				column_w - 20.0, 18, Color.WHITE)
		draw_string(font, origin + Vector2(0, 160), "%s / %s" % [motif.family, motif.group],
				HORIZONTAL_ALIGNMENT_LEFT, column_w - 20.0, 15, Color(1, 1, 1, 0.6))
	draw_string(font, Vector2(14, 30), "Crests %d-%d of %d (%s cut)" % [first, mini(first + PER_PAGE,
			HalvesCrests.motif_count()) - 1, HalvesCrests.motif_count(), "vertical" if cut == 0 else "horizontal"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)


func _card(at: Vector2, card: Vector2) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = HalvesPalette.IVORY
	box.set_corner_radius_all(int(card.x * 0.15))
	draw_style_box(box, Rect2(at, card))
