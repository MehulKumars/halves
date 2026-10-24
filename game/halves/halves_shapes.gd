class_name HalvesShapes
extends RefCounted
## Draws half shapes in code: each half sits with its cut edge on the centre line, so drawing side
## a and side b at the same centre gives the whole shape. Used by tile views and the snap effect.
## Polygons get an anti-aliased outline in the same colour (Compatibility polygons have hard edges).

const ARC_STEPS: int = 20
## (v3) Crests are drawn a little larger than v2 shapes: their detail needs the room.
const CREST_SCALE: float = 1.18

static var _cache: Dictionary[int, PackedVector2Array] = {}


## The half for `face`, centred on the origin, `extent` = half the whole shape's width.
static func half_polygon(face: int, extent: float) -> PackedVector2Array:
	var key := HalvesFace.pair_key(face) << 1 | HalvesFace.side(face)
	key = key * 4096 + int(extent * 8.0)
	if _cache.has(key):
		return _cache[key]
	var points := _build(face, extent)
	_cache[key] = points
	return points


## Draws one half (and its mark) on `canvas`, centred at `center`.
static func draw_half(canvas: CanvasItem, face: int, center: Vector2, extent: float, offset: Vector2 = Vector2.ZERO) -> void:
	if not HalvesFace.is_valid(face):
		return
	if HalvesFace.is_crest(face):
		HalvesCrest.draw(canvas, HalvesFace.pair_key(face), HalvesFace.side(face), center, extent * CREST_SCALE,
				HalvesPalette.face_color(face), HalvesPalette.face_paper(face), offset)
		return
	var colour := HalvesPalette.shape_color(HalvesFace.shape(face))
	var points := half_polygon(face, extent)
	var moved := PackedVector2Array()
	moved.resize(points.size())
	for i in points.size():
		moved[i] = points[i] + center + offset
	canvas.draw_colored_polygon(moved, colour)
	var outline := moved.duplicate()
	outline.append(moved[0])
	canvas.draw_polyline(outline, colour, maxf(1.0, extent * 0.03), true)
	_draw_mark(canvas, face, moved, extent)


## Both halves of a pair joined (`gap` pixels apart along the cut), as in the snap moment.
static func draw_whole(canvas: CanvasItem, pair_key: int, center: Vector2, extent: float, gap: float) -> void:
	var face_a := pair_key << 1 | HalvesFace.SIDE_A
	var away := Vector2(gap * 0.5, 0.0) if HalvesFace.cut(face_a) == HalvesFace.Cut.VERTICAL else Vector2(0.0, gap * 0.5)
	draw_half(canvas, face_a, center, extent, -away)
	draw_half(canvas, face_a | HalvesFace.SIDE_B, center, extent, away)


static func _build(face: int, h: float) -> PackedVector2Array:
	var vertical := HalvesFace.cut(face) == HalvesFace.Cut.VERTICAL
	var a := HalvesFace.side(face) == HalvesFace.SIDE_A
	var points := PackedVector2Array()
	match HalvesFace.shape(face):
		HalvesFace.Shape.CIRCLE:
			# Godot's y points down: PI/2 is the bottom, 3PI/2 the top.
			var start := (PI * 0.5 if a else -PI * 0.5) if vertical else (PI if a else 0.0)
			for i in ARC_STEPS + 1:
				var angle := start + PI * i / ARC_STEPS
				points.append(Vector2(cos(angle), sin(angle)) * h)
		HalvesFace.Shape.TRIANGLE:
			var base := h * 0.86
			var apex := -h * 0.94
			points = [Vector2(0, apex), Vector2(-h if a else h, base), Vector2(0, base)]
		HalvesFace.Shape.SQUARE:
			var s := h * 0.86
			if vertical:
				points = [Vector2(0, -s), Vector2(-s if a else s, -s), Vector2(-s if a else s, s), Vector2(0, s)]
			else:
				points = [Vector2(-s, 0), Vector2(-s, -s if a else s), Vector2(s, -s if a else s), Vector2(s, 0)]
		HalvesFace.Shape.DIAMOND:
			if vertical:
				points = [Vector2(0, -h), Vector2(-h if a else h, 0), Vector2(0, h)]
			else:
				points = [Vector2(-h, 0), Vector2(0, -h if a else h), Vector2(h, 0)]
	return points


## A small ivory dot, or a short line parallel to the cut, at the half's centre of area.
static func _draw_mark(canvas: CanvasItem, face: int, points: PackedVector2Array, h: float) -> void:
	var mark := HalvesFace.mark(face)
	if mark == HalvesFace.Mark.NONE:
		return
	var centre := _centroid(points)
	if mark == HalvesFace.Mark.DOT:
		canvas.draw_circle(centre, h * 0.13, HalvesPalette.IVORY, true, -1.0, true)
	else:
		var along := Vector2(0, h * 0.42) if HalvesFace.cut(face) == HalvesFace.Cut.VERTICAL else Vector2(h * 0.42, 0)
		canvas.draw_line(centre - along, centre + along, HalvesPalette.IVORY, maxf(2.0, h * 0.09), true)


static func _centroid(points: PackedVector2Array) -> Vector2:
	var area := 0.0
	var sum := Vector2.ZERO
	for i in points.size():
		var p := points[i]
		var q := points[(i + 1) % points.size()]
		var cross := p.x * q.y - q.x * p.y
		area += cross
		sum += (p + q) * cross
	if absf(area) < 0.0001:
		return points[0]
	return sum / (3.0 * area)
