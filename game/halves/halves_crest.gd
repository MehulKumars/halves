class_name HalvesCrest
extends RefCounted
## Draws crests (kamon) in code from a motif's spec in HalvesCrests: compass-and-ruler primitives in
## unit space (radius 1, y down), as layers of ink and paper (paper is the tile colour, painted over
## ink to cut holes). A half is every layer clipped to a half-plane, so both halves make the whole.

## Segments of a full circle; arcs use a share of it.
const STEPS: int = 40
## The clipping half-plane, as a rectangle well past the crest.
const FAR: float = 4.0
## A crest inside a ring is drawn at this size; the ring's band is RING_BAND wide.
const RING_INNER: float = 0.76
const RING_BAND: float = 0.12

static var _whole: Dictionary[int, Array] = {}
static var _halves: Dictionary[int, Array] = {}


## The whole crest of a motif: [{"ink": bool, "polygons": Array[PackedVector2Array]}], in order.
static func layers(motif: int) -> Array[Dictionary]:
	if not _whole.has(motif):
		_whole[motif] = _build(HalvesCrests.MOTIFS[motif].spec)
	var out: Array[Dictionary] = []
	out.assign(_whole[motif])
	return out


## One half: side a is x <= 0 (vertical cut) or y <= 0 (horizontal cut); side b the other.
static func half_layers(motif: int, cut: int, side: int) -> Array[Dictionary]:
	var key := motif * 4 + cut * 2 + side
	if not _halves.has(key):
		var keep: Rect2
		if cut == HalvesFace.Cut.VERTICAL:
			keep = Rect2(-FAR, -FAR, FAR, FAR * 2.0) if side == HalvesFace.SIDE_A else Rect2(0.0, -FAR, FAR, FAR * 2.0)
		else:
			keep = Rect2(-FAR, -FAR, FAR * 2.0, FAR) if side == HalvesFace.SIDE_A else Rect2(-FAR, 0.0, FAR * 2.0, FAR)
		var clip := PackedVector2Array([keep.position, Vector2(keep.end.x, keep.position.y), keep.end,
				Vector2(keep.position.x, keep.end.y)])
		var cut_layers: Array[Dictionary] = []
		for layer in layers(motif):
			var pieces: Array[PackedVector2Array] = []
			for polygon: PackedVector2Array in layer.polygons:
				for piece in Geometry2D.intersect_polygons(polygon, clip):
					if piece.size() >= 3:
						pieces.append(piece)
			if not pieces.is_empty():
				cut_layers.append({"ink": layer.ink, "polygons": pieces, "edges": _edges(pieces, cut)})
		_halves[key] = cut_layers
	var out: Array[Dictionary] = []
	out.assign(_halves[key])
	return out


## Draws a crest pair's half (side 0 or 1) or the whole crest (side -1); extent = crest radius.
static func draw(canvas: CanvasItem, pair: int, side: int, center: Vector2, extent: float, ink: Color,
		paper: Color, offset: Vector2 = Vector2.ZERO) -> void:
	var motif := HalvesCrests.motif_of(pair)
	if motif < 0:
		return
	var list := layers(motif) if side < 0 else half_layers(motif, HalvesCrests.cut_of(pair), side)
	var place := Transform2D(0.0, Vector2(extent, extent), 0.0, center + offset)
	var edge := maxf(1.0, extent * 0.025)
	for layer in list:
		var colour := ink if layer.ink else paper
		for polygon: PackedVector2Array in layer.polygons:
			canvas.draw_colored_polygon(place * polygon, colour)
		# Compatibility polygons have hard edges: a thin anti-aliased outline softens them.
		canvas.draw_multiline(place * (layer.edges as PackedVector2Array), colour, edge, true)


## Outline segments (pairs of points) of polygons, without the ones lying on the cut line (a
## half's straight edge must stay crisp against its mate, and an outline there shows as a seam).
static func _edges(polygons: Array[PackedVector2Array], cut: int = -1) -> PackedVector2Array:
	var segments := PackedVector2Array()
	for polygon in polygons:
		for i in polygon.size():
			var p := polygon[i]
			var q := polygon[(i + 1) % polygon.size()]
			if cut == HalvesFace.Cut.VERTICAL and absf(p.x) < 0.001 and absf(q.x) < 0.001:
				continue
			if cut == HalvesFace.Cut.HORIZONTAL and absf(p.y) < 0.001 and absf(q.y) < 0.001:
				continue
			segments.append(p)
			segments.append(q)
	return segments


static func _build(spec: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ring := bool(spec.get("ring", false))
	var size := RING_INNER if ring else 1.0
	if ring:
		_paint(out, true, [_circle(Vector2.ZERO, 1.0)])
		_paint(out, false, [_circle(Vector2.ZERO, 1.0 - RING_BAND)])
	match spec.kind:
		&"flower":
			_flower(out, spec, size)
		&"tomoe":
			_tomoe(out, spec, size)
		&"moon":
			_moon(out, spec, size)
		&"star":
			_paint(out, true, [_star(Vector2.ZERO, 0.98 * size, 0.98 * size * _star_waist(int(spec.points)), int(spec.points), -PI * 0.5)])
		&"ripple":
			_ripple(out, spec)
		&"whirl":
			_whirl(out, spec)
		&"diamond":
			_diamond(out, spec, size)
		&"hexagon":
			_hexagon(out, spec, size)
		&"frame":
			_frame(out, size)
		&"ginkgo":
			_ginkgo(out, spec, size)
		&"sasa":
			_sasa(out, spec, size)
		&"maple":
			_maple(out, size)
		&"katabami":
			_katabami(out, size)
		&"kashiwa":
			_kashiwa(out, size)
		&"fan":
			_fan(out, spec, size)
		&"umbrella":
			_umbrella(out, size)
		&"bell":
			_bell(out, size)
		&"lantern":
			_lantern(out, size)
		&"drum":
			_drum(out, size)
		&"butterfly":
			_butterfly(out, size)
		&"dragonfly":
			_dragonfly(out, size)
		&"goose":
			_goose(out, spec, size)
		&"sun":
			_sun(out, spec, size)
	return _fit(out)


## Scales a crest that reaches past the unit circle back inside it (the contract's promise, and
## what keeps every crest the same size on a tile).
static func _fit(out: Array[Dictionary]) -> Array[Dictionary]:
	var reach := 0.0
	for layer in out:
		for polygon: PackedVector2Array in layer.polygons:
			for p in polygon:
				reach = maxf(reach, p.length())
	if reach <= 1.0:
		return out
	var shrink := Transform2D(0.0, Vector2.ONE / reach, 0.0, Vector2.ZERO)
	for layer in out:
		var scaled: Array[PackedVector2Array] = []
		for polygon: PackedVector2Array in layer.polygons:
			scaled.append(shrink * polygon)
		layer.polygons = scaled
		layer.edges = _edges(scaled)
	return out


static func _paint(out: Array[Dictionary], ink: bool, polygons: Array) -> void:
	var list: Array[PackedVector2Array] = []
	list.assign(polygons)
	out.append({"ink": ink, "polygons": list, "edges": _edges(list)})


# --- Kinds ---------------------------------------------------------------------------------------

## Petals around a core, first petal up: round (plum), notched (cherry) or pointed (bellflower).
static func _flower(out: Array[Dictionary], spec: Dictionary, size: float) -> void:
	var count := int(spec.petals)
	var reach := 0.98 * size
	var petals: Array[PackedVector2Array] = []
	for i in count:
		var angle := -PI * 0.5 + TAU * i / count
		var petal := _petal(spec.petal, count, reach)
		petals.append(Transform2D(angle + PI * 0.5, Vector2.ZERO) * petal)
	petals.append(_circle(Vector2.ZERO, reach * 0.3))
	_paint(out, true, petals)
	match spec.center:
		&"hole":
			_paint(out, false, [_circle(Vector2.ZERO, reach * 0.15)])
		&"dot":
			_paint(out, false, [_circle(Vector2.ZERO, reach * 0.2)])
			_paint(out, true, [_circle(Vector2.ZERO, reach * 0.1)])


## One petal pointing up (towards -y) from the centre.
static func _petal(style: StringName, count: int, reach: float) -> PackedVector2Array:
	var spread := sin(PI / count)
	match style:
		&"round":
			var r := 0.55 * spread * 1.25 * reach
			return _circle(Vector2(0.0, -(reach - r)), r)
		&"notched":
			var r := 0.5 * spread * 1.2 * reach
			var body := _ellipse(Vector2(0.0, -(reach - r * 1.2)), r, r * 1.2)
			var notch := PackedVector2Array([Vector2(0.0, -(reach - r * 0.55)), Vector2(-r * 0.42, -reach * 1.1),
					Vector2(r * 0.42, -reach * 1.1)])
			var cut := Geometry2D.clip_polygons(body, notch)
			return _largest(cut) if not cut.is_empty() else body
		_:
			return _lens(Vector2(0.0, -reach * 0.1), Vector2(0.0, -reach), reach * spread * 0.44)


## Commas swirling round the centre; "right" is the mirror image of "left".
static func _tomoe(out: Array[Dictionary], spec: Dictionary, size: float) -> void:
	var count := int(spec.count)
	# Head distance, head radius and tail sweep per count, then scaled to fit.
	var head_at := [0.22, 0.42, 0.5][count - 1] as float
	var head_r := [0.5, 0.38, 0.32][count - 1] as float
	var sweep := deg_to_rad([200.0, 140.0, 100.0][count - 1] as float)
	var fit := 0.98 * size / (head_at + head_r)
	var mirror := Vector2(-1.0, 1.0) if spec.turn == &"right" else Vector2.ONE
	var commas: Array[PackedVector2Array] = []
	for j in count:
		var start := -PI * 0.5 + TAU * j / count
		var outer := head_at + head_r
		var tail := PackedVector2Array()
		var steps := 24
		for i in steps + 1:
			var t := float(i) / steps
			tail.append(Vector2.from_angle(start + sweep * t) * outer)
		for i in range(steps, -1, -1):
			var t := float(i) / steps
			tail.append(Vector2.from_angle(start + sweep * t) * lerpf(head_at, outer, t))
		var head := _circle(Vector2.from_angle(start) * head_at, head_r)
		var merged := Geometry2D.merge_polygons(head, tail)
		var comma := _largest(merged) if not merged.is_empty() else head
		var scaled := PackedVector2Array()
		for p in comma:
			scaled.append(p * fit * mirror)
		commas.append(scaled)
	_paint(out, true, commas)


## A crescent (thin or thick, with or without a star) or a full moon.
static func _moon(out: Array[Dictionary], spec: Dictionary, size: float) -> void:
	var r := 0.9 * size
	if spec.phase == &"full":
		_paint(out, true, [_circle(Vector2.ZERO, r * 0.82)])
		return
	var bite := _circle(Vector2(r * 0.3, -r * 0.3), r * (0.84 if spec.phase == &"thin" else 0.66))
	var crescent := Geometry2D.clip_polygons(_circle(Vector2.ZERO, r), bite)
	_paint(out, true, [_largest(crescent)])
	if bool(spec.star):
		_paint(out, true, [_star(Vector2(r * 0.3, -r * 0.3), r * 0.3, r * 0.13, 5, -PI * 0.5)])


## Concentric rings, optionally round a drop.
static func _ripple(out: Array[Dictionary], spec: Dictionary) -> void:
	var rings := int(spec.rings)
	var band := 0.14
	var step := (0.98 - (0.22 if bool(spec.dot) else 0.12)) / rings
	for i in rings:
		var r := 0.98 - step * i
		_paint(out, true, [_circle(Vector2.ZERO, r)])
		_paint(out, false, [_circle(Vector2.ZERO, r - band)])
	if bool(spec.dot):
		_paint(out, true, [_circle(Vector2.ZERO, 0.17)])


## A spiral band (or two), winding out from the centre.
static func _whirl(out: Array[Dictionary], spec: Dictionary) -> void:
	var arms := int(spec.arms)
	var turns := 2.4 / arms
	var mirror := Vector2(-1.0, 1.0) if spec.turn == &"right" else Vector2.ONE
	var start_r := 0.06
	var growth := (0.9 - start_r) / (turns * TAU)
	var width := growth * TAU / arms * 0.48
	var bands: Array[PackedVector2Array] = []
	for arm in arms:
		var offset := TAU * arm / arms
		var outer_edge := PackedVector2Array()
		var inner_edge := PackedVector2Array()
		var steps := int(turns * 40)
		for i in steps + 1:
			var theta := turns * TAU * i / steps
			var r := start_r + growth * theta
			var dir := Vector2.from_angle(theta + offset - PI * 0.5)
			outer_edge.append(dir * (r + width * 0.5) * mirror)
			inner_edge.append(dir * maxf(r - width * 0.5, 0.0) * mirror)
		inner_edge.reverse()
		bands.append(outer_edge + inner_edge)
	bands.append(_circle(Vector2.ZERO, 0.13))
	_paint(out, true, bands)


## One outlined diamond with a centre, or four solid diamonds.
static func _diamond(out: Array[Dictionary], spec: Dictionary, size: float) -> void:
	if int(spec.count) == 4:
		var small: Array[PackedVector2Array] = []
		for c in [Vector2(0.0, -0.49), Vector2(-0.34, 0.0), Vector2(0.34, 0.0), Vector2(0.0, 0.49)]:
			small.append(_rhombus(c * size, 0.31 * size, 0.46 * size))
		_paint(out, true, small)
		return
	_paint(out, true, [_rhombus(Vector2.ZERO, 0.66 * size, 0.98 * size)])
	_paint(out, false, [_rhombus(Vector2.ZERO, 0.4 * size, 0.6 * size)])
	_paint(out, true, [_rhombus(Vector2.ZERO, 0.17 * size, 0.26 * size)])


## A double-lined hexagon (tortoise shell), empty or with a drop or a diamond inside.
static func _hexagon(out: Array[Dictionary], spec: Dictionary, size: float) -> void:
	var r := 0.98 * size
	_paint(out, true, [_regular(Vector2.ZERO, r, 6, -PI * 0.5)])
	_paint(out, false, [_regular(Vector2.ZERO, r * 0.84, 6, -PI * 0.5)])
	_paint(out, true, [_regular(Vector2.ZERO, r * 0.72, 6, -PI * 0.5)])
	_paint(out, false, [_regular(Vector2.ZERO, r * 0.58, 6, -PI * 0.5)])
	match spec.inner:
		&"dot":
			_paint(out, true, [_circle(Vector2.ZERO, r * 0.24)])
		&"diamond":
			_paint(out, true, [_rhombus(Vector2.ZERO, r * 0.26, r * 0.38)])


## A well frame: four bars crossing like #, turned 45 degrees.
static func _frame(out: Array[Dictionary], size: float) -> void:
	var bars: Array[PackedVector2Array] = []
	var turn := Transform2D(PI * 0.25, Vector2.ZERO)
	var half := 0.62 * size
	var gap := 0.27 * size
	var thick := 0.09 * size
	for sign_x in [-1.0, 1.0]:
		bars.append(turn * _box(Vector2(gap * sign_x, 0.0), Vector2(thick, half)))
		bars.append(turn * _box(Vector2(0.0, gap * sign_x), Vector2(half, thick)))
	_paint(out, true, bars)


## Ginkgo: a fan-shaped leaf with a notch and a stem (one, or two leaning apart).
static func _ginkgo(out: Array[Dictionary], spec: Dictionary, size: float) -> void:
	var leaves: Array[PackedVector2Array] = []
	var notches: Array[PackedVector2Array] = []
	var count := int(spec.count)
	var lean := [0.0] if count == 1 else [-0.5, 0.5]
	var scale := size * (1.0 if count == 1 else 0.62)
	# Two leaves turn about the foot of their stems, so they open like a V.
	var foot := Vector2(0.0, 0.96) * scale
	var lift := Vector2.ZERO if count == 1 else Vector2(0.0, 0.94 * size) - foot
	for angle: float in lean:
		var turn := Transform2D(angle, foot + lift) * Transform2D(0.0, -foot)
		var pivot := Vector2(0.0, 0.58) * scale
		var blade := PackedVector2Array([pivot])
		for i in 17:
			var a := deg_to_rad(-90.0 - 34.0 + 68.0 * i / 16.0)
			blade.append(pivot + Vector2.from_angle(a) * 1.42 * scale)
		leaves.append(turn * blade)
		leaves.append(turn * _box(Vector2(0.0, 0.76 * scale), Vector2(0.045, 0.2) * scale))
		var top := pivot.y - 1.42 * scale
		notches.append(turn * PackedVector2Array([Vector2(0.0, top + 0.3 * scale), Vector2(-0.1 * scale, top - 0.05),
				Vector2(0.1 * scale, top - 0.05)]))
	_paint(out, true, leaves)
	_paint(out, false, notches)


## Bamboo leaves fanning up from one point (three, or five).
static func _sasa(out: Array[Dictionary], spec: Dictionary, size: float) -> void:
	var count := int(spec.leaves)
	var leaves: Array[PackedVector2Array] = []
	var base := Vector2(0.0, 0.62) * size
	var spread := 52.0 if count == 3 else 34.0
	for i in count:
		var angle := deg_to_rad(-90.0 + spread * (i - (count - 1) * 0.5))
		var tip := base + Vector2.from_angle(angle) * 1.5 * size
		leaves.append(_lens(base + Vector2.from_angle(angle) * 0.12 * size, tip, 0.17 * size))
	leaves.append(_box(Vector2(0.0, 0.78 * size), Vector2(0.05, 0.18) * size))
	_paint(out, true, leaves)
	_paint(out, false, [_lens(base + Vector2(0.0, -0.2 * size), base + Vector2(0.0, -1.35 * size), 0.025 * size)])


## A maple leaf: five pointed lobes on a short stem.
static func _maple(out: Array[Dictionary], size: float) -> void:
	# Lobes from lower left round to lower right (angles grow clockwise on screen): [degrees, length].
	var lobes := [[160.0, 0.66], [215.0, 0.88], [270.0, 0.98], [325.0, 0.88], [380.0, 0.66]]
	var outline := PackedVector2Array()
	var centre := Vector2(0.0, 0.08) * size
	for k in lobes.size():
		var lobe: Array = lobes[k]
		var angle := deg_to_rad(lobe[0] as float)
		if k > 0:
			var prev: Array = lobes[k - 1]
			var mid := deg_to_rad(((prev[0] as float) + (lobe[0] as float)) * 0.5)
			outline.append(centre + Vector2.from_angle(mid) * 0.34 * size)
		outline.append(centre + Vector2.from_angle(angle - 0.2) * (lobe[1] as float) * 0.55 * size)
		outline.append(centre + Vector2.from_angle(angle) * (lobe[1] as float) * size)
		outline.append(centre + Vector2.from_angle(angle + 0.2) * (lobe[1] as float) * 0.55 * size)
	outline.append(centre + Vector2(0.0, 0.3) * size)
	_paint(out, true, [outline, _box(Vector2(0.0, 0.62) * size, Vector2(0.04, 0.3) * size)])


## Wood sorrel: three heart-shaped leaves round the centre.
static func _katabami(out: Array[Dictionary], size: float) -> void:
	var leaves: Array[PackedVector2Array] = []
	for i in 3:
		var turn := Transform2D(TAU * i / 3.0, Vector2.ZERO)
		var r := 0.27 * size
		var lobe_l := _circle(Vector2(-r * 0.85, -0.66 * size), r)
		var lobe_r := _circle(Vector2(r * 0.85, -0.66 * size), r)
		var point := PackedVector2Array([Vector2(-r * 1.95, -0.6 * size), Vector2(r * 1.95, -0.6 * size), Vector2(0.0, -0.1 * size)])
		var heart := _largest(Geometry2D.merge_polygons(_largest(Geometry2D.merge_polygons(lobe_l, lobe_r)), point))
		leaves.append(turn * heart)
	leaves.append(_circle(Vector2.ZERO, 0.12 * size))
	_paint(out, true, leaves)


## Three oak leaves with wavy edges, fanned from the bottom.
static func _kashiwa(out: Array[Dictionary], size: float) -> void:
	var leaves: Array[PackedVector2Array] = []
	for angle: float in [-0.55, 0.0, 0.55]:
		var turn := Transform2D(angle, Vector2(0.0, 0.66 * size))
		var leaf := _circle(Vector2(0.0, -0.36 * size), 0.2 * size)
		for k in 5:
			var y := (-0.5 - 0.19 * k) * size
			var r := (0.23 - 0.03 * k) * size
			leaf = _largest(Geometry2D.merge_polygons(leaf, _circle(Vector2(0.0, y), r)))
		leaves.append(turn * leaf)
		leaves.append(turn * _box(Vector2(0.0, -0.12 * size), Vector2(0.035, 0.14) * size))
	_paint(out, true, leaves)
	var veins: Array[PackedVector2Array] = []
	for angle: float in [-0.55, 0.0, 0.55]:
		veins.append(Transform2D(angle, Vector2(0.0, 0.66 * size)) * _box(Vector2(0.0, -0.72 * size), Vector2(0.016, 0.36) * size))
	_paint(out, false, veins)


## A folding fan, ribs showing; in a ring when spec.ring.
static func _fan(out: Array[Dictionary], spec: Dictionary, size: float) -> void:
	var pivot := Vector2(0.0, 0.42) * size
	var leaf := PackedVector2Array()
	var steps := 24
	for i in steps + 1:
		leaf.append(pivot + Vector2.from_angle(deg_to_rad(-155.0 + 130.0 * i / steps)) * 1.12 * size)
	for i in range(steps, -1, -1):
		leaf.append(pivot + Vector2.from_angle(deg_to_rad(-155.0 + 130.0 * i / steps)) * 0.42 * size)
	_paint(out, true, [leaf, _circle(pivot, 0.13 * size)])
	var ribs: Array[PackedVector2Array] = []
	for i in range(1, 6):
		var angle := deg_to_rad(-155.0 + 130.0 * i / 6.0)
		ribs.append(_lens(pivot + Vector2.from_angle(angle) * 0.46 * size, pivot + Vector2.from_angle(angle) * 1.06 * size, 0.022 * size))
	_paint(out, false, ribs)


## An umbrella seen from above: a disc with ribs and a hub.
static func _umbrella(out: Array[Dictionary], size: float) -> void:
	_paint(out, true, [_regular(Vector2.ZERO, 0.96 * size, 16, 0.0)])
	var ribs: Array[PackedVector2Array] = []
	for i in 8:
		var angle := TAU * i / 8.0
		ribs.append(_lens(Vector2.from_angle(angle) * 0.2 * size, Vector2.from_angle(angle) * 0.9 * size, 0.03 * size))
	_paint(out, false, ribs + [_circle(Vector2.ZERO, 0.2 * size)])
	_paint(out, true, [_circle(Vector2.ZERO, 0.11 * size)])


## A round bell with its slot and a loop on top.
static func _bell(out: Array[Dictionary], size: float) -> void:
	var body := Vector2(0.0, 0.14) * size
	_paint(out, true, [_circle(body, 0.76 * size), _circle(Vector2(0.0, -0.74 * size), 0.2 * size)])
	_paint(out, false, [_circle(Vector2(0.0, -0.74 * size), 0.1 * size), _box(body + Vector2(0.0, 0.18 * size), Vector2(0.8, 0.05) * size),
			_circle(body + Vector2(0.0, 0.42 * size), 0.1 * size)])


## A paper lantern: an oval with ribs and caps.
static func _lantern(out: Array[Dictionary], size: float) -> void:
	_paint(out, true, [_ellipse(Vector2.ZERO, 0.62 * size, 0.78 * size), _box(Vector2(0.0, -0.84 * size), Vector2(0.34, 0.08) * size),
			_box(Vector2(0.0, 0.84 * size), Vector2(0.34, 0.08) * size)])
	var bands: Array[PackedVector2Array] = []
	for y: float in [-0.48, -0.16, 0.16, 0.48]:
		bands.append(_box(Vector2(0.0, y * size), Vector2(0.7, 0.04) * size))
	_paint(out, false, bands)


## A hand drum: two heads joined at a narrow waist, with cords.
static func _drum(out: Array[Dictionary], size: float) -> void:
	var body := PackedVector2Array([Vector2(-0.58, -0.78), Vector2(0.58, -0.78), Vector2(0.12, 0.0), Vector2(0.58, 0.78),
			Vector2(-0.58, 0.78), Vector2(-0.12, 0.0)])
	var scaled := PackedVector2Array()
	for p in body:
		scaled.append(p * size)
	_paint(out, true, [scaled, _ellipse(Vector2(0.0, -0.8 * size), 0.68 * size, 0.16 * size),
			_ellipse(Vector2(0.0, 0.8 * size), 0.68 * size, 0.16 * size)])
	_paint(out, false, [_ellipse(Vector2(0.0, -0.8 * size), 0.5 * size, 0.07 * size), _ellipse(Vector2(0.0, 0.8 * size), 0.5 * size, 0.07 * size),
			_box(Vector2(0.0, 0.0), Vector2(0.5, 0.025) * size)])


## A butterfly seen from above: four wings, a body and feelers.
static func _butterfly(out: Array[Dictionary], size: float) -> void:
	var wings: Array[PackedVector2Array] = []
	for side: float in [-1.0, 1.0]:
		wings.append(Transform2D(side * 0.55, Vector2(side * 0.44, -0.24) * size) * _ellipse(Vector2.ZERO, 0.44 * size, 0.3 * size))
		wings.append(Transform2D(-side * 0.6, Vector2(side * 0.33, 0.36) * size) * _ellipse(Vector2.ZERO, 0.3 * size, 0.22 * size))
		wings.append(_lens(Vector2(side * 0.04, -0.5) * size, Vector2(side * 0.36, -0.9) * size, 0.025 * size))
		wings.append(_circle(Vector2(side * 0.36, -0.9) * size, 0.06 * size))
	wings.append(_ellipse(Vector2(0.0, 0.05 * size), 0.08 * size, 0.56 * size))
	_paint(out, true, wings)
	var spots: Array[PackedVector2Array] = []
	for side: float in [-1.0, 1.0]:
		spots.append(_circle(Vector2(side * 0.52, -0.3) * size, 0.1 * size))
	_paint(out, false, spots)


## A dragonfly seen from above: four long wings, a long body and a head.
static func _dragonfly(out: Array[Dictionary], size: float) -> void:
	var parts: Array[PackedVector2Array] = []
	for side: float in [-1.0, 1.0]:
		parts.append(_lens(Vector2(side * 0.06, -0.42) * size, Vector2(side * 0.96, -0.3) * size, 0.13 * size))
		parts.append(_lens(Vector2(side * 0.06, -0.24) * size, Vector2(side * 0.86, 0.02) * size, 0.12 * size))
	parts.append(_ellipse(Vector2(0.0, 0.22 * size), 0.07 * size, 0.74 * size))
	parts.append(_circle(Vector2(0.0, -0.62 * size), 0.17 * size))
	_paint(out, true, parts)


## A flying goose: wings in a shallow V, a head; one bird, or one in a ring.
static func _goose(out: Array[Dictionary], spec: Dictionary, size: float) -> void:
	var parts: Array[PackedVector2Array] = []
	for side: float in [-1.0, 1.0]:
		parts.append(_lens(Vector2(0.0, 0.05) * size, Vector2(side * 0.98, -0.42) * size, 0.2 * size))
	parts.append(_ellipse(Vector2(0.0, 0.18 * size), 0.18 * size, 0.34 * size))
	parts.append(_circle(Vector2(0.0, -0.22 * size), 0.13 * size))
	_paint(out, true, parts)
	if spec.get("crest", false):
		_paint(out, false, [_circle(Vector2(0.0, 0.2 * size), 0.07 * size)])


## A radiant sun: a disc in a ring, with pointed rays all round.
static func _sun(out: Array[Dictionary], spec: Dictionary, size: float) -> void:
	var rays := int(spec.rays)
	var parts: Array[PackedVector2Array] = [_circle(Vector2.ZERO, 0.6 * size)]
	for i in rays:
		var angle := -PI * 0.5 + TAU * i / rays
		parts.append(_lens(Vector2.from_angle(angle) * 0.5 * size, Vector2.from_angle(angle) * 0.98 * size, 0.1 * size))
	_paint(out, true, parts)
	_paint(out, false, [_circle(Vector2.ZERO, 0.47 * size)])
	_paint(out, true, [_circle(Vector2.ZERO, 0.36 * size)])


# --- Primitives ----------------------------------------------------------------------------------

static func _circle(c: Vector2, r: float) -> PackedVector2Array:
	return _ellipse(c, r, r)


static func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in STEPS:
		var angle := TAU * i / STEPS
		points.append(c + Vector2(cos(angle) * rx, sin(angle) * ry))
	return points


## A pointed oval from a to b: two circular arcs, each `bulge` away from the chord at the middle.
static func _lens(a: Vector2, b: Vector2, bulge: float) -> PackedVector2Array:
	var chord := b - a
	var length := chord.length()
	var mid := (a + b) * 0.5
	var normal := Vector2(-chord.y, chord.x) / length
	var radius := (length * length * 0.25 + bulge * bulge) / (2.0 * bulge)
	var points := PackedVector2Array()
	var steps := 14
	for side in [1.0, -1.0]:
		var centre: Vector2 = mid - normal * side * (radius - bulge)
		var from: Vector2 = (a if side > 0.0 else b) - centre
		var to: Vector2 = (b if side > 0.0 else a) - centre
		var sweep := wrapf(to.angle() - from.angle(), -PI, PI)
		for i in steps:
			points.append(centre + Vector2.from_angle(from.angle() + sweep * i / steps) * radius)
	return points


static func _regular(c: Vector2, r: float, sides: int, rotation: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in sides:
		points.append(c + Vector2.from_angle(rotation + TAU * i / sides) * r)
	return points


static func _star(c: Vector2, outer: float, inner: float, points: int, rotation: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points * 2:
		var r := outer if i % 2 == 0 else inner
		out.append(c + Vector2.from_angle(rotation + PI * i / points) * r)
	return out


## How deep a star's points cut in, by number of points.
static func _star_waist(points: int) -> float:
	return 0.42 if points <= 5 else (0.52 if points == 6 else 0.6)


static func _rhombus(c: Vector2, half_w: float, half_h: float) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0.0, -half_h), c + Vector2(half_w, 0.0), c + Vector2(0.0, half_h),
			c + Vector2(-half_w, 0.0)])


static func _box(c: Vector2, half: Vector2) -> PackedVector2Array:
	return PackedVector2Array([c - half, c + Vector2(half.x, -half.y), c + half, c + Vector2(-half.x, half.y)])


## The piece with the largest area (boolean operations can leave slivers).
static func _largest(pieces: Array[PackedVector2Array]) -> PackedVector2Array:
	var best := PackedVector2Array()
	var best_area := -1.0
	for piece in pieces:
		var area := absf(_area(piece))
		if area > best_area:
			best_area = area
			best = piece
	return best


static func _area(points: PackedVector2Array) -> float:
	var sum := 0.0
	for i in points.size():
		var p := points[i]
		var q := points[(i + 1) % points.size()]
		sum += p.x * q.y - q.x * p.y
	return sum * 0.5
