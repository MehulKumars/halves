class_name HalvesScenery
extends Control
## A place drawn in code, the "Drawn" choice of backgrounds: layered silhouettes of the same place
## as the chapter's photo (sky, sun or moon, clouds, hills, a landmark, water, trees, lanterns).
## Each element is its own CanvasItem drawn once; only clouds, water shimmer and stars move.

## Animated layers redraw at most this often (water shimmer); clouds and stars only move or fade.
const SHIMMER_FPS: float = 10.0

## Element types and their keys (x, y are 0..1 of the width and height; sizes are noted per type):
## sky c[] at[] · glow p r(H) c · disc p r(H) c · stars n until c · clouds y n c s speed ·
## ridge y a f c floor · fuji x y w(W) h(H) c snow floor · water y c[] · shimmer y c n x[] ·
## reflect y a of[] · mist y h c · ground y c[] · path vp w c rails · pagoda x y h tiers c lit ·
## torii x y w c top legs · tower x y h c line · city y top c win[] n · bamboo n c w[] avoid[] ·
## trees pts[[x y r ground]] c[] trunk · pines y n h[] c snow · houses side vp n c roof win near ·
## lanterns pts r c · gates vp n c dark · pavilion x y w c roof snow · branch from to c bloom[] ·
## dots rect n c[] r[] · beams n c
const SCENES: Dictionary = {
	"fuji": [
		{"t": "sky", "c": ["39467a", "7d77a8", "d9a1ad", "f6caa9"], "at": [0.0, 0.3, 0.48, 0.6]},
		{"t": "glow", "p": [0.72, 0.56], "r": 0.32, "c": Color(1.0, 0.85, 0.7, 0.55)},
		{"t": "clouds", "y": 0.16, "n": 4, "c": Color(1.0, 0.86, 0.88, 0.32), "s": 1.2, "speed": 5.0},
		{"t": "clouds", "y": 0.33, "n": 3, "c": Color(1.0, 0.8, 0.78, 0.28), "s": 0.8, "speed": 8.0},
		{"t": "ridge", "y": 0.585, "a": 0.035, "f": 2.2, "c": "5b628f", "floor": 0.6, "seed": 1},
		{"t": "fuji", "x": 0.52, "y": 0.6, "w": 1.25, "h": 0.17, "c": "3d4677", "snow": "f7eef1", "floor": 0.6},
		{"t": "ridge", "y": 0.598, "a": 0.008, "f": 9.0, "c": "262c4f", "floor": 0.606, "seed": 2},
		{"t": "water", "y": 0.6, "c": ["9a98c4", "5d6296", "2c3160"]},
		{"t": "reflect", "y": 0.603, "a": 0.32, "of": [4, 5, 6]},
		{"t": "mist", "y": 0.6, "h": 0.05, "c": Color(1.0, 0.9, 0.92, 0.22)},
		{"t": "shimmer", "y": 0.6, "c": Color(1.0, 0.9, 0.86, 0.45), "n": 46, "x": [0.0, 1.0]},
	],
	"sakura": [
		{"t": "sky", "c": ["bcd6ee", "e6eef6", "f8e8ee"], "at": [0.0, 0.35, 0.55]},
		{"t": "ridge", "y": 0.53, "a": 0.035, "f": 2.5, "c": "c4cfdf", "seed": 3},
		{"t": "ground", "y": 0.555, "c": ["b4d394", "86b06a", "5f8a4c"]},
		{"t": "path", "vp": [0.5, 0.555], "w": 0.95, "c": "a99583", "rails": "6d5f59"},
		{"t": "trees", "c": ["f7cddb", "f0b4c9", "fde6ee", "e9a4bf"], "trunk": "4b3a40", "pts": [
			[0.02, 0.4, 0.2, 0.72], [0.19, 0.47, 0.12, 0.62], [0.3, 0.515, 0.065, 0.585], [0.37, 0.535, 0.035, 0.565],
			[0.98, 0.4, 0.2, 0.72], [0.81, 0.47, 0.12, 0.62], [0.7, 0.515, 0.065, 0.585], [0.63, 0.535, 0.035, 0.565]]},
		{"t": "dots", "rect": [0.0, 0.62, 1.0, 1.0], "n": 160, "c": ["fbe3ec", "f4c3d4"], "r": [2.0, 4.5]},
		{"t": "branch", "from": [-0.05, 0.03], "to": [0.62, 0.13], "c": "4b3a40", "bloom": ["f7cddb", "fde6ee", "eeaac3"]},
	],
	"kyoto": [
		{"t": "sky", "c": ["8798b3", "c9cdd6", "efe0cd"], "at": [0.0, 0.32, 0.6]},
		{"t": "ridge", "y": 0.5, "a": 0.03, "f": 2.0, "c": "a7aebd", "seed": 4},
		{"t": "pagoda", "x": 0.4, "y": 0.6, "h": 0.42, "tiers": 5, "c": "2e2b35"},
		{"t": "trees", "c": ["3d4a3c", "4a5a45", "34402f"], "trunk": "2a2a2a", "pts": [[0.22, 0.56, 0.06, 0.6], [0.58, 0.57, 0.05, 0.6]]},
		{"t": "path", "vp": [0.55, 0.6], "w": 1.3, "c": "8d898e"},
		{"t": "houses", "side": -1, "vp": [0.55, 0.6], "n": 5, "c": "5b4b43", "roof": "2a2730", "win": "ffd08a"},
		{"t": "houses", "side": 1, "vp": [0.55, 0.6], "n": 5, "c": "6a574c", "roof": "2a2730", "win": "ffd08a"},
	],
	"bamboo": [
		{"t": "sky", "c": ["eef4dc", "c3d9a4", "8fb276"], "at": [0.0, 0.4, 1.0]},
		{"t": "beams", "n": 4, "c": Color(1.0, 1.0, 0.88, 0.1)},
		{"t": "bamboo", "n": 26, "c": "a9c58f", "w": [0.007, 0.013], "seed": 1},
		{"t": "bamboo", "n": 15, "c": "6c9a57", "w": [0.014, 0.024], "seed": 2},
		{"t": "ground", "y": 0.52, "c": ["8fae6c", "5d7a45"]},
		{"t": "path", "vp": [0.46, 0.52], "w": 1.0, "c": "c9c1a9"},
		{"t": "bamboo", "n": 7, "c": "34552f", "w": [0.03, 0.05], "seed": 3, "avoid": [0.28, 0.62]},
	],
	"torii": [
		{"t": "sky", "c": ["2c3864", "6f6290", "ec9c7a", "ffd8a2"], "at": [0.0, 0.3, 0.48, 0.585]},
		{"t": "disc", "p": [0.5, 0.56], "r": 0.022, "c": "fff3d0"},
		{"t": "glow", "p": [0.5, 0.56], "r": 0.28, "c": Color(1.0, 0.82, 0.55, 0.6)},
		{"t": "clouds", "y": 0.2, "n": 5, "c": Color(0.2, 0.17, 0.3, 0.5), "s": 1.4, "speed": 4.0},
		{"t": "clouds", "y": 0.38, "n": 4, "c": Color(1.0, 0.72, 0.58, 0.35), "s": 0.9, "speed": 7.0},
		{"t": "ridge", "y": 0.585, "a": 0.028, "f": 3.0, "c": "3e3d5c", "floor": 0.6, "seed": 7},
		{"t": "water", "y": 0.6, "c": ["d39a82", "6a5172", "2a2440"]},
		{"t": "reflect", "y": 0.601, "a": 0.35, "of": [5]},
		{"t": "shimmer", "y": 0.6, "c": Color(1.0, 0.88, 0.66, 0.75), "n": 60, "x": [0.36, 0.64]},
		{"t": "reflect", "y": 0.73, "a": 0.22, "of": [10]},
		{"t": "torii", "x": 0.5, "y": 0.73, "w": 0.6, "c": "d2462f", "top": "2a1c22", "legs": true},
	],
	"tokyo": [
		{"t": "sky", "c": ["0a0f2e", "1d2860", "573f7a", "b26f6a"], "at": [0.0, 0.38, 0.6, 0.72]},
		{"t": "stars", "n": 60, "until": 0.45, "c": Color(1, 1, 1, 0.8)},
		{"t": "city", "y": 0.8, "top": 0.6, "c": "232a56", "win": ["7183c6"], "n": 30, "seed": 1},
		{"t": "glow", "p": [0.5, 0.62], "r": 0.34, "c": Color(1.0, 0.6, 0.3, 0.35)},
		{"t": "tower", "x": 0.5, "y": 0.82, "h": 0.56, "c": "ff8a2b", "line": "ffd497"},
		{"t": "city", "y": 1.0, "top": 0.7, "c": "11162f", "win": ["ffd27a", "a8d8ff", "fff4e0"], "n": 16, "seed": 2},
	],
	"nara": [
		{"t": "sky", "c": ["d6e4ec", "f2e6c9"], "at": [0.0, 0.5]},
		{"t": "ground", "y": 0.36, "c": ["c9b77a", "8a7a4c", "6a5c38"]},
		{"t": "mist", "y": 0.5, "h": 0.12, "c": Color(1.0, 0.95, 0.85, 0.35)},
		{"t": "ground", "y": 0.6, "c": ["7d7248", "5a5234"]},
		{"t": "path", "vp": [0.62, 0.6], "w": 1.5, "c": "c47f61"},
		{"t": "dots", "rect": [0.0, 0.62, 1.0, 1.0], "n": 420, "c": ["b8432c", "d9652f", "e8a03c", "8e2f22"], "r": [2.0, 5.0]},
		{"t": "lanterns", "pts": [[0.2, 0.66], [0.33, 0.625], [0.83, 0.64], [0.74, 0.62]], "r": 0.012, "c": "ffe0a0", "post": "4a4038"},
		{"t": "trees", "c": ["f2c14e", "e8a23a", "d9822b", "f6d97c", "c9a43a"], "trunk": "3b3026", "pts": [
			[0.05, 0.12, 0.3, 0.66], [0.45, 0.06, 0.28, 0.6], [0.88, 0.14, 0.3, 0.66], [0.3, 0.3, 0.16, 0.6], [0.7, 0.32, 0.14, 0.6]]},
	],
	"kiyomizu": [
		{"t": "sky", "c": ["060a1d", "111a3c", "1f2651"], "at": [0.0, 0.4, 0.62]},
		{"t": "stars", "n": 70, "until": 0.5, "c": Color(1, 1, 1, 0.75)},
		{"t": "glow", "p": [0.58, 0.42], "r": 0.36, "c": Color(1.0, 0.6, 0.25, 0.35)},
		{"t": "pagoda", "x": 0.58, "y": 0.6, "h": 0.4, "tiers": 3, "c": "e48c38", "lit": "ffd27f"},
		{"t": "glow", "p": [0.5, 0.82], "r": 0.6, "c": Color(1.0, 0.5, 0.2, 0.3)},
		{"t": "trees", "c": ["c2412b", "e8743a", "ffb04a", "8f2a22", "f39a52"], "trunk": "2a1418", "pts": [
			[0.1, 0.62, 0.22, 1.0], [0.45, 0.7, 0.2, 1.0], [0.85, 0.6, 0.22, 1.0], [0.3, 0.85, 0.22, 1.1], [0.72, 0.88, 0.24, 1.1],
			[0.0, 0.92, 0.2, 1.1], [1.0, 0.95, 0.2, 1.1]]},
	],
	"kinkaku": [
		{"t": "sky", "c": ["c3ccd8", "e8ecf1"], "at": [0.0, 0.5]},
		{"t": "ridge", "y": 0.5, "a": 0.04, "f": 2.0, "c": "dbe1e8", "seed": 8},
		{"t": "pines", "y": 0.58, "n": 26, "h": [0.06, 0.12], "c": "3a4945", "snow": "f2f5f8"},
		{"t": "pavilion", "x": 0.5, "y": 0.6, "w": 0.6, "c": "d8a83c", "roof": "3a3328", "snow": "f7f9fb"},
		{"t": "water", "y": 0.6, "c": ["aab3bf", "7d8898"]},
		{"t": "reflect", "y": 0.6, "a": 0.42, "of": [3, 2]},
		{"t": "ground", "y": 0.84, "c": ["f4f6f9", "e0e5ec"]},
		{"t": "branch", "from": [1.05, 0.02], "to": [0.35, 0.1], "c": "3a3a42", "bloom": ["ffffff", "eef2f7", "dfe6ee"]},
	],
	"ginzan": [
		{"t": "sky", "c": ["13204c", "2c4a8c", "5873b0"], "at": [0.0, 0.3, 0.55]},
		{"t": "ridge", "y": 0.38, "a": 0.05, "f": 2.0, "c": "1e2c50", "seed": 9},
		{"t": "pines", "y": 0.42, "n": 34, "h": [0.04, 0.09], "c": "17213e", "snow": "dfe7f3"},
		{"t": "path", "vp": [0.5, 0.56], "w": 0.55, "c": "1b2238"},
		{"t": "shimmer", "y": 0.62, "c": Color(1.0, 0.82, 0.5, 0.55), "n": 40, "x": [0.32, 0.68], "to": 1.0},
		{"t": "houses", "side": -1, "vp": [0.5, 0.56], "n": 4, "c": "3a2c28", "roof": "e9eef6", "win": "ffcf7a", "tall": 1.6},
		{"t": "houses", "side": 1, "vp": [0.5, 0.56], "n": 4, "c": "40302a", "roof": "e9eef6", "win": "ffcf7a", "tall": 1.6},
		{"t": "lanterns", "pts": [[0.3, 0.6], [0.7, 0.6], [0.2, 0.68], [0.8, 0.68], [0.38, 0.575], [0.62, 0.575]], "r": 0.016, "c": "ffe2a6", "post": "1d1d24"},
	],
	"inari": [
		{"t": "sky", "c": ["17301f", "2c5236", "1b2f22"], "at": [0.0, 0.45, 1.0]},
		{"t": "glow", "p": [0.5, 0.46], "r": 0.22, "c": Color(1.0, 0.95, 0.8, 0.85)},
		{"t": "path", "vp": [0.5, 0.47], "w": 0.95, "c": "c9c0b1"},
		{"t": "gates", "vp": [0.5, 0.47], "n": 30, "c": "e04b2b", "dark": "171717"},
	],
}

static var _glow_texture: Texture2D
static var _gradients: Dictionary[String, Texture2D] = {}

var scene_id: String = ""
var _elements: Array = []
var _layers: Array[Node2D] = []
var _time: float = 0.0
var _shimmer_wait: float = 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


static func has_scene(id: String) -> bool:
	return SCENES.has(id)


func set_scene(id: String) -> void:
	if id == scene_id:
		return
	scene_id = id
	for layer in _layers:
		layer.queue_free()
	_layers.clear()
	_elements = SCENES.get(id, [])
	for i in _elements.size():
		var layer := Node2D.new()
		layer.draw.connect(_paint_layer.bind(layer, i))
		add_child(layer)
		_layers.append(layer)
	set_process(Juice.motion_scale > 0.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		for layer in _layers:
			layer.queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	_shimmer_wait -= delta
	var redraw_shimmer := _shimmer_wait <= 0.0
	if redraw_shimmer:
		_shimmer_wait = 1.0 / SHIMMER_FPS
	for i in _elements.size():
		var e: Dictionary = _elements[i]
		match str(e.t):
			"clouds":
				_layers[i].position.x = fposmod(_time * float(e.get("speed", 6.0)), size.x)
			"stars":
				_layers[i].modulate.a = 0.8 + 0.2 * sin(_time * 0.9)
			"shimmer":
				if redraw_shimmer:
					_layers[i].queue_redraw()


func _paint_layer(ci: CanvasItem, index: int) -> void:
	_paint(ci, _elements[index], 1.0)


func _paint(ci: CanvasItem, e: Dictionary, k: float) -> void:
	match str(e.t):
		"sky": _sky(ci, e, k)
		"glow": _glow(ci, _p(e.p), float(e.r) * size.y, _col(e.c, k))
		"disc": _disc(ci, e, k)
		"stars": _stars(ci, e, k)
		"clouds": _clouds(ci, e, k)
		"ridge": _ridge(ci, e, k)
		"fuji": _fuji(ci, e, k)
		"water": _band(ci, float(e.y) * size.y, size.y, e.c, k)
		"ground": _band(ci, float(e.y) * size.y, size.y, e.c, k)
		"shimmer": _shimmer(ci, e, k)
		"reflect": _reflect(ci, e)
		"mist": _mist(ci, e, k)
		"path": _path(ci, e, k)
		"pagoda": _pagoda(ci, e, k)
		"torii": _torii(ci, e, k)
		"tower": _tower(ci, e, k)
		"city": _city(ci, e, k)
		"bamboo": _bamboo(ci, e, k)
		"trees": _trees(ci, e, k)
		"pines": _pines(ci, e, k)
		"houses": _houses(ci, e, k)
		"lanterns": _lanterns(ci, e, k)
		"gates": _gates(ci, e, k)
		"pavilion": _pavilion(ci, e, k)
		"branch": _branch(ci, e, k)
		"dots": _dots(ci, e, k)
		"beams": _beams(ci, e, k)


# -- helpers -----------------------------------------------------------------------------------

static func _col(value: Variant, k: float = 1.0) -> Color:
	var c: Color = value if value is Color else Color(str(value))
	c.a *= k
	return c


func _p(pair: Array) -> Vector2:
	return Vector2(float(pair[0]) * size.x, float(pair[1]) * size.y)


func _rng(e: Dictionary, salt: int = 0) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([scene_id, int(e.get("seed", 0)), str(e.t), salt])
	return rng


## A vertical gradient texture through `colors` at `stops` (0..1), cached.
static func gradient(colors: Array, stops: Array = [], k: float = 1.0) -> Texture2D:
	var key := "%s|%s|%.2f" % [colors, stops, k]
	if _gradients.has(key):
		return _gradients[key]
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in colors.size():
		offsets.append(float(stops[i]) if i < stops.size() else float(i) / maxf(1.0, colors.size() - 1))
		cols.append(_col(colors[i], k))
	g.offsets = offsets
	g.colors = cols
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 4
	tex.height = 256
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	_gradients[key] = tex
	return tex


## A soft round light: white in the middle fading to nothing, tinted when drawn.
static func glow_texture() -> Texture2D:
	if _glow_texture != null:
		return _glow_texture
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.55, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.16), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	_glow_texture = tex
	return tex


func _glow(ci: CanvasItem, at: Vector2, radius: float, colour: Color) -> void:
	ci.draw_texture_rect(glow_texture(), Rect2(at - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, colour)


## A filled shape with a smooth (antialiased) outline in the same colour.
static func _shape(ci: CanvasItem, points: PackedVector2Array, colour: Color) -> void:
	if points.size() < 3:
		return
	ci.draw_colored_polygon(points, colour)
	var outline := points.duplicate()
	outline.append(points[0])
	ci.draw_polyline(outline, colour, 1.2, true)


static func _quad(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, d: Vector2, colour: Color) -> void:
	_shape(ci, PackedVector2Array([a, b, c, d]), colour)


# -- sky, light, weather ------------------------------------------------------------------------

func _sky(ci: CanvasItem, e: Dictionary, k: float) -> void:
	ci.draw_texture_rect(gradient(e.c, e.get("at", []), k), Rect2(Vector2.ZERO, size), false)


func _band(ci: CanvasItem, top: float, bottom: float, colors: Variant, k: float) -> void:
	var list: Array = colors if colors is Array else [colors, colors]
	ci.draw_texture_rect(gradient(list, [], k), Rect2(0, top, size.x, bottom - top), false)


func _disc(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var at := _p(e.p)
	var r := float(e.r) * size.y
	var c := _col(e.c, k)
	_glow(ci, at, r * 3.0, Color(c, c.a * 0.6))
	ci.draw_circle(at, r, c, true, -1.0, true)


func _stars(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var rng := _rng(e)
	var c := _col(e.c, k)
	for i in int(e.n):
		var at := Vector2(rng.randf() * size.x, pow(rng.randf(), 1.4) * float(e.until) * size.y)
		ci.draw_circle(at, rng.randf_range(0.8, 2.2), Color(c, c.a * rng.randf_range(0.35, 1.0)), true, -1.0, true)


## Soft clouds (stretched glows) drawn twice, one width apart, so the drifting layer wraps cleanly.
func _clouds(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var rng := _rng(e)
	var c := _col(e.c, k)
	var scale := float(e.get("s", 1.0)) * size.y * 0.03
	for i in int(e.n):
		var base := Vector2(rng.randf() * size.x, (float(e.y) + rng.randf_range(-0.05, 0.05)) * size.y)
		var length := rng.randf_range(4.0, 8.0) * scale
		var puffs: Array = []
		for j in 6:
			var t := float(j) / 5.0
			var w := length * rng.randf_range(0.5, 0.9)
			var h := scale * rng.randf_range(1.2, 2.2) * (0.5 + 0.5 * sin(t * PI))
			puffs.append(Rect2(Vector2((t - 0.5) * length * 1.4 - w * 0.5, -h * 0.6 - rng.randf() * scale * 0.6), Vector2(w, h * 1.4)))
		for shift in [0.0, -size.x]:
			for puff: Rect2 in puffs:
				ci.draw_texture_rect(glow_texture(), Rect2(base + Vector2(shift, 0) + puff.position, puff.size), false, c)



func _shimmer(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var rng := _rng(e, int(_time * SHIMMER_FPS) % 4)
	var c := _col(e.c, k)
	var span: Array = e.get("x", [0.0, 1.0])
	var top := float(e.y) * size.y
	var bottom := float(e.get("to", 0.9)) * size.y
	for i in int(e.n):
		var depth := pow(rng.randf(), 1.6)
		var y := lerpf(top + 2.0, bottom, depth)
		var spread := lerpf(0.4, 1.0, depth)
		var mid := lerpf(float(span[0]), float(span[1]), 0.5)
		var x := (mid + (rng.randf() - 0.5) * (float(span[1]) - float(span[0])) * spread) * size.x
		var length := lerpf(6.0, 34.0, depth) * rng.randf_range(0.5, 1.2)
		var a := c.a * rng.randf_range(0.25, 1.0) * (0.6 + 0.4 * sin(_time * 2.0 + i))
		ci.draw_line(Vector2(x - length * 0.5, y), Vector2(x + length * 0.5, y), Color(c, a), lerpf(1.0, 2.5, depth), true)


## Elements `of` drawn upside down below the line `y`, faded to `a`.
func _reflect(ci: CanvasItem, e: Dictionary) -> void:
	var line := float(e.y) * size.y
	ci.draw_set_transform(Vector2(0, line * 2.0), 0.0, Vector2(1, -1))
	for index: int in e.of:
		_paint(ci, _elements[index], float(e.a))
	ci.draw_set_transform(Vector2.ZERO)


func _mist(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var c := _col(e.c, k)
	var h := float(e.h) * size.y
	var tex := gradient([Color(c, 0.0), c, Color(c, 0.0)], [0.0, 0.5, 1.0])
	ci.draw_texture_rect(tex, Rect2(0, float(e.y) * size.y - h * 0.5, size.x, h), false)


func _beams(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var rng := _rng(e)
	var c := _col(e.c, k)
	for i in int(e.n):
		var x := rng.randf_range(0.1, 0.9) * size.x
		var w := rng.randf_range(0.04, 0.1) * size.x
		var lean := size.y * 0.25
		_quad(ci, Vector2(x, 0), Vector2(x + w, 0), Vector2(x + w + lean + w, size.y * 0.75), Vector2(x + lean, size.y * 0.75), c)


# -- land ---------------------------------------------------------------------------------------

## A noisy hill line at height y (a = amplitude), filled down to `floor`.
func _ridge(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = int(e.get("seed", 0))
	noise.frequency = float(e.get("f", 2.0)) / maxf(1.0, size.x) * 1.0
	noise.fractal_octaves = 4
	var clip: Array = e.get("clip", [0.0, 1.0])
	var x0 := float(clip[0]) * size.x
	var x1 := float(clip[1]) * size.x
	var floor_y := float(e.get("floor", 1.0)) * size.y
	var points := PackedVector2Array([Vector2(x0, floor_y)])
	var steps := 90
	for i in steps + 1:
		var x := lerpf(x0, x1, float(i) / steps)
		var n := noise.get_noise_1d(x * 1.0)
		points.append(Vector2(x, (float(e.y) - float(e.a) * (0.5 + n)) * size.y))
	points.append(Vector2(x1, floor_y))
	_shape(ci, points, _col(e.c, k))


func _fuji(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var cx := float(e.x) * size.x
	var base := float(e.y) * size.y
	var half := float(e.w) * size.x * 0.5
	var h := float(e.h) * size.y
	var floor_y := float(e.get("floor", e.y)) * size.y
	var top_half := half * 0.06
	var body := PackedVector2Array([Vector2(cx - half, floor_y)])
	var steps := 40
	for i in steps + 1:
		var t := float(i) / steps
		body.append(Vector2(lerpf(cx - half, cx - top_half, t), base - h * pow(t, 2.1)))
	for i in steps + 1:
		var t := 1.0 - float(i) / steps
		body.append(Vector2(lerpf(cx + half, cx + top_half, t), base - h * pow(t, 2.1)))
	body.append(Vector2(cx + half, floor_y))
	_shape(ci, body, _col(e.c, k))
	# Snow cap: the top 40% of the cone, its lower edge in gullies.
	var cap := 0.6
	var snow := PackedVector2Array()
	var rng := _rng(e)
	var gullies := 11
	var cap_left := lerpf(cx - half, cx - top_half, pow(cap, 1.0 / 2.1))
	var cap_right := lerpf(cx + half, cx + top_half, pow(cap, 1.0 / 2.1))
	snow.append(Vector2(cx - top_half, base - h))
	snow.append(Vector2(cx + top_half, base - h))
	for i in range(steps, -1, -1):
		var t := float(i) / steps
		if t < pow(cap, 1.0 / 2.1):
			break
		snow.append(Vector2(lerpf(cx + half, cx + top_half, t), base - h * pow(t, 2.1)))
	for i in gullies + 1:
		var t := float(i) / gullies
		var x := lerpf(cap_right, cap_left, t)
		var dip := h * (0.06 + 0.12 * rng.randf()) * (1.0 if i % 2 == 0 else 0.25)
		snow.append(Vector2(x, base - h * cap + dip * sin(t * PI * 0.5 + 0.8)))
	for i in steps + 1:
		var t := float(i) / steps
		if t < pow(cap, 1.0 / 2.1):
			continue
		snow.append(Vector2(lerpf(cx - half, cx - top_half, t), base - h * pow(t, 2.1)))
	_shape(ci, snow, _col(e.snow, k))


## A road or river narrowing to its vanishing point; optional rails along it.
func _path(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var vp := _p(e.vp)
	var half := float(e.w) * size.x * 0.5
	var left := Vector2(size.x * 0.5 - half + (vp.x - size.x * 0.5), size.y)
	var right := Vector2(size.x * 0.5 + half + (vp.x - size.x * 0.5), size.y)
	_quad(ci, left, right, vp + Vector2(size.x * 0.004, 0), vp - Vector2(size.x * 0.004, 0), _col(e.c, k))
	if e.has("rails"):
		var c := _col(e.rails, k)
		for side: float in [-0.18, 0.18]:
			var foot := Vector2(vp.x + side * size.x, size.y)
			ci.draw_line(foot, vp + Vector2(side * 2.0, 0), c, 4.0, true)
		for i in 14:
			var t := pow(float(i) / 14.0, 2.0)
			var y := lerpf(vp.y, size.y, t)
			var w := lerpf(1.0, size.x * 0.24, t)
			ci.draw_line(Vector2(vp.x - w, y), Vector2(vp.x + w, y), Color(c, c.a * 0.6), lerpf(1.0, 9.0, t), true)


func _dots(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var rng := _rng(e)
	var r: Array = e.rect
	var colors: Array = e.c
	for i in int(e.n):
		var t := pow(rng.randf(), 0.7)
		var at := Vector2(rng.randf_range(float(r[0]), float(r[2])) * size.x, lerpf(float(r[1]), float(r[3]), t) * size.y)
		var radius := lerpf(float(e.r[0]), float(e.r[1]), t) * size.y / 1600.0 * 1.6
		ci.draw_circle(at, radius, _col(colors[i % colors.size()], k), true, -1.0, true)


# -- landmarks ----------------------------------------------------------------------------------

## A roof with upturned eaves: `w` wide at `y` (its lower edge), `t` thick.
static func _roof(ci: CanvasItem, cx: float, y: float, w: float, t: float, colour: Color) -> void:
	var half := w * 0.5
	var lift := t * 0.9
	var points := PackedVector2Array([
		Vector2(cx - half, y - lift), Vector2(cx - half * 0.9, y), Vector2(cx + half * 0.9, y), Vector2(cx + half, y - lift),
		Vector2(cx + half * 0.72, y - t), Vector2(cx + half * 0.32, y - t * 1.9), Vector2(cx - half * 0.32, y - t * 1.9),
		Vector2(cx - half * 0.72, y - t)])
	_shape(ci, points, colour)


func _pagoda(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var cx := float(e.x) * size.x
	var base := float(e.y) * size.y
	var h := float(e.h) * size.y
	var c := _col(e.c, k)
	var tiers := int(e.get("tiers", 5))
	var spire := h * 0.24
	var tier_h := (h - spire) / tiers
	var w0 := h * 0.5
	ci.draw_rect(Rect2(cx - w0 * 0.42, base - tier_h * 0.25, w0 * 0.84, tier_h * 0.25), c)
	var y := base - tier_h * 0.25
	for i in tiers:
		var w := w0 * (1.0 - 0.09 * i)
		var body_h := tier_h * 0.5
		ci.draw_rect(Rect2(cx - w * 0.3, y - body_h, w * 0.6, body_h), c)
		if e.has("lit"):
			var lit := _col(e.lit, k)
			for j in 3:
				ci.draw_rect(Rect2(cx - w * 0.22 + j * w * 0.16, y - body_h * 0.8, w * 0.1, body_h * 0.6), lit)
		y -= body_h
		_roof(ci, cx, y, w, tier_h * 0.26, c)
		y -= tier_h * 0.5
	ci.draw_rect(Rect2(cx - h * 0.008, y - spire, h * 0.016, spire), c)
	for j in 7:
		var ry := y - spire * (0.15 + 0.1 * j)
		ci.draw_rect(Rect2(cx - h * 0.02, ry, h * 0.04, h * 0.006), c)


func _torii(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var cx := float(e.x) * size.x
	var base := float(e.y) * size.y
	var w := float(e.w) * size.x
	var h := w * 0.92
	var c := _col(e.c, k)
	var top := _col(e.get("top", e.c), k)
	var leg := w * 0.065
	for side: float in [-1.0, 1.0]:
		var x := cx + side * w * 0.3
		_quad(ci, Vector2(x - leg * 0.5, base - h * 0.86), Vector2(x + leg * 0.5, base - h * 0.86),
			Vector2(x + leg * 0.62, base), Vector2(x - leg * 0.62, base), c)
		if e.get("legs", false):
			for off: float in [-0.13, 0.13]:
				var lx := x + off * w
				ci.draw_rect(Rect2(lx - leg * 0.28, base - h * 0.42, leg * 0.56, h * 0.42), c)
			ci.draw_rect(Rect2(x - w * 0.14, base - h * 0.4, w * 0.28, leg * 0.35), c)
	# Nuki (lower beam), the strut, the shimaki and the dark kasagi with upturned ends.
	ci.draw_rect(Rect2(cx - w * 0.42, base - h * 0.66, w * 0.84, leg * 0.7), c)
	ci.draw_rect(Rect2(cx - leg * 0.35, base - h * 0.84, leg * 0.7, h * 0.18), c)
	ci.draw_rect(Rect2(cx - w * 0.46, base - h * 0.86, w * 0.92, leg * 0.75), c)
	var y := base - h * 0.86
	_shape(ci, PackedVector2Array([Vector2(cx - w * 0.56, y - leg * 1.6), Vector2(cx - w * 0.5, y - leg * 0.55),
		Vector2(cx + w * 0.5, y - leg * 0.55), Vector2(cx + w * 0.56, y - leg * 1.6), Vector2(cx + w * 0.5, y - leg * 1.25),
		Vector2(cx - w * 0.5, y - leg * 1.25)]), top)


## A lattice tower (Tokyo Tower): splayed legs, two decks and a mast, with a lighter lattice.
func _tower(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var cx := float(e.x) * size.x
	var base := float(e.y) * size.y
	var h := float(e.h) * size.y
	var c := _col(e.c, k)
	var line := _col(e.line, k)
	var half_at := func(t: float) -> float: return h * (0.2 * pow(1.0 - t, 2.2) + 0.012)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in 41:
		var t := float(i) / 40.0 * 0.82
		left.append(Vector2(cx - half_at.call(t), base - h * t))
		right.append(Vector2(cx + half_at.call(t), base - h * t))
	var outline := left.duplicate()
	right.reverse()
	outline.append_array(right)
	_shape(ci, outline, c)
	ci.draw_rect(Rect2(cx - h * 0.006, base - h, h * 0.012, h * 0.2), c)
	for deck: float in [0.3, 0.6]:
		var hw: float = half_at.call(deck) * 1.5
		ci.draw_rect(Rect2(cx - hw, base - h * deck - h * 0.02, hw * 2.0, h * 0.03), line)
	for i in 16:
		var t0 := float(i) / 16.0 * 0.82
		var t1 := float(i + 1) / 16.0 * 0.82
		ci.draw_line(Vector2(cx - half_at.call(t0), base - h * t0), Vector2(cx + half_at.call(t1), base - h * t1), Color(line, line.a * 0.55), 1.4, true)
		ci.draw_line(Vector2(cx + half_at.call(t0), base - h * t0), Vector2(cx - half_at.call(t1), base - h * t1), Color(line, line.a * 0.55), 1.4, true)
	# The arch between the legs.
	ci.draw_circle(Vector2(cx, base + h * 0.02), half_at.call(0.0) * 0.55, Color(0.04, 0.05, 0.12, k))


func _city(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var rng := _rng(e)
	var c := _col(e.c, k)
	var windows: Array = e.win
	var bottom := float(e.y) * size.y
	var top := float(e.top) * size.y
	var x := -rng.randf() * 40.0
	while x < size.x:
		var w := rng.randf_range(0.05, 0.13) * size.x
		var bh := rng.randf_range(0.25, 1.0) * (bottom - top)
		var r := Rect2(x, bottom - bh, w, bh)
		ci.draw_rect(r, c)
		var cell := maxf(6.0, size.x * 0.014)
		var cols := int(w / cell / 1.6)
		var rows := int(bh / cell / 1.8)
		for row in rows:
			for col in cols:
				if rng.randf() < 0.42:
					var wc := _col(windows[rng.randi() % windows.size()], k)
					ci.draw_rect(Rect2(x + cell * 0.5 + col * cell * 1.6, bottom - bh + cell * 0.6 + row * cell * 1.8, cell * 0.8, cell), Color(wc, wc.a * rng.randf_range(0.5, 1.0)))
		x += w + rng.randf_range(-0.01, 0.01) * size.x


func _bamboo(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var rng := _rng(e)
	var c := _col(e.c, k)
	var dark := c.darkened(0.25)
	var avoid: Array = e.get("avoid", [])
	for i in int(e.n):
		var x := rng.randf() * size.x
		if not avoid.is_empty() and x > float(avoid[0]) * size.x and x < float(avoid[1]) * size.x:
			x = float(avoid[0]) * size.x - rng.randf() * size.x * 0.25 if rng.randf() < 0.5 else float(avoid[1]) * size.x + rng.randf() * size.x * 0.25
		var w := rng.randf_range(float(e.w[0]), float(e.w[1])) * size.x
		var lean := rng.randf_range(-0.03, 0.03) * size.x
		var top := Vector2(x + lean, -10.0)
		var foot := Vector2(x, size.y + 10.0)
		_quad(ci, top - Vector2(w * 0.4, 0), top + Vector2(w * 0.4, 0), foot + Vector2(w * 0.5, 0), foot - Vector2(w * 0.5, 0), c)
		var node_gap := rng.randf_range(0.07, 0.11) * size.y
		var y := rng.randf() * node_gap
		while y < size.y:
			var at := top.lerp(foot, y / size.y)
			ci.draw_line(at - Vector2(w * 0.5, 0), at + Vector2(w * 0.5, 0), dark, maxf(1.5, w * 0.12), true)
			y += node_gap
		for j in 6:
			var at2 := top.lerp(foot, rng.randf_range(0.0, 0.35))
			var dir := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(0.1, 0.5)).normalized()
			var length := w * rng.randf_range(2.5, 4.5)
			_shape(ci, PackedVector2Array([at2, at2 + dir * length * 0.5 + dir.orthogonal() * w * 0.35, at2 + dir * length]), c)


## Round canopies of overlapping discs (a darker underside, lighter tops), each on a trunk down to
## its ground line.
func _trees(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var rng := _rng(e)
	var colors: Array = e.c
	var trunk := _col(e.trunk, k)
	for p: Array in e.pts:
		var at := _p([p[0], p[1]])
		var r := float(p[2]) * size.y
		var ground := float(p[3]) * size.y
		ci.draw_line(at, Vector2(at.x, ground), trunk, maxf(2.0, r * 0.14), true)
		ci.draw_line(at + Vector2(0, r * 0.3), at + Vector2(-r * 0.5, -r * 0.2), trunk, maxf(1.5, r * 0.07), true)
		ci.draw_line(at + Vector2(0, r * 0.2), at + Vector2(r * 0.45, -r * 0.25), trunk, maxf(1.5, r * 0.07), true)
		for pass_index in 3:
			var lift := Vector2(-0.12, -0.18) * r * pass_index
			var shade_k := [0.28, 0.08, -0.12][pass_index] as float
			for j in 10 - pass_index * 2:
				var off := Vector2.from_angle(rng.randf() * TAU) * r * sqrt(rng.randf()) * Vector2(1.1, 0.75)
				var base_colour := _col(colors[rng.randi() % colors.size()], k)
				var shade := base_colour.darkened(shade_k) if shade_k > 0.0 else base_colour.lightened(-shade_k)
				ci.draw_circle(at + off + lift, r * rng.randf_range(0.28, 0.46) * (1.0 - 0.15 * pass_index), shade, true, -1.0, true)



func _pines(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var rng := _rng(e)
	var c := _col(e.c, k)
	var snow := _col(e.get("snow", e.c), k)
	var base := float(e.y) * size.y
	for i in int(e.n):
		var x := rng.randf() * size.x
		var h := rng.randf_range(float(e.h[0]), float(e.h[1])) * size.y
		var y := base + rng.randf_range(-0.02, 0.02) * size.y
		var w := h * 0.42
		for j in 3:
			var t := float(j) / 3.0
			var top := y - h * (0.45 + t * 0.55)
			var bottom := y - h * t * 0.55
			var half := w * (1.0 - t * 0.35) * 0.5
			_shape(ci, PackedVector2Array([Vector2(x, top), Vector2(x + half, bottom), Vector2(x - half, bottom)]), c)
			_shape(ci, PackedVector2Array([Vector2(x, top), Vector2(x + half * 0.45, lerpf(top, bottom, 0.4)),
				Vector2(x, lerpf(top, bottom, 0.3)), Vector2(x - half * 0.45, lerpf(top, bottom, 0.4))]), snow)


## A row of townhouses down one side of a street, shrinking toward the vanishing point.
func _houses(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var side := float(e.side)
	var vp := _p(e.vp)
	var n := int(e.n)
	var tall := float(e.get("tall", 1.0))
	var wall := _col(e.c, k)
	var roof := _col(e.roof, k)
	var win := _col(e.win, k)
	var edge := 0.0 if side < 0.0 else size.x
	# Near facade: from the screen edge, height tall * 0.36 H, reaching 0.62 of the way to the path.
	var near_bottom := size.y * 1.02
	var near_top := near_bottom - size.y * 0.36 * tall
	var far := 1.0
	for i in n:
		var t0 := 1.0 - pow(0.62, i)
		var t1 := 1.0 - pow(0.62, i + 1)
		var x0 := lerpf(edge, vp.x - side * size.x * 0.03, t0)
		var x1 := lerpf(edge, vp.x - side * size.x * 0.03, t1)
		var b0 := lerpf(near_bottom, vp.y, t0)
		var b1 := lerpf(near_bottom, vp.y, t1)
		var top0 := lerpf(near_top, vp.y, t0)
		var top1 := lerpf(near_top, vp.y, t1)
		_quad(ci, Vector2(x0, top0), Vector2(x1, top1), Vector2(x1, b1), Vector2(x0, b0), wall.darkened(0.08 * i))
		var eave := (b0 - top0) * 0.12
		_quad(ci, Vector2(x0, top0 - eave * 1.2), Vector2(x1, top1 - eave * 1.2 * (1.0 - t1 + t0)),
			Vector2(x1, top1 + eave * 0.5 * far), Vector2(x0, top0 + eave * 0.5), roof)
		var mid := 0.55
		_quad(ci, Vector2(x0, lerpf(top0, b0, mid) - eave * 0.4), Vector2(x1, lerpf(top1, b1, mid) - eave * 0.4),
			Vector2(x1, lerpf(top1, b1, mid) + eave * 0.2), Vector2(x0, lerpf(top0, b0, mid) + eave * 0.2), roof.darkened(0.2))
		for row: float in [0.3, 0.75]:
			for j in 2:
				var u := 0.25 + j * 0.4
				var wx := lerpf(x0, x1, u)
				var wy := lerpf(lerpf(top0, b0, row), lerpf(top1, b1, row), u)
				var wh := lerpf(b0 - top0, b1 - top1, u) * 0.12
				ci.draw_rect(Rect2(wx - wh * 0.4, wy - wh * 0.5, wh * 0.8, wh), win)
				_glow(ci, Vector2(wx, wy), wh * 1.6, Color(win, win.a * 0.35))


func _lanterns(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var c := _col(e.c, k)
	var r := float(e.r) * size.y
	for p: Array in e.pts:
		var at := _p(p)
		if e.has("post"):
			var post := _col(e.post, k)
			ci.draw_line(at + Vector2(0, r), at + Vector2(0, r * 7.0), post, maxf(2.0, r * 0.35), true)
		_glow(ci, at, r * 5.0, Color(c, c.a * 0.55))
		ci.draw_rect(Rect2(at - Vector2(r * 0.7, r), Vector2(r * 1.4, r * 2.0)), c)


## A tunnel of torii gates (Fushimi Inari): frames from the vanishing point to the viewer.
func _gates(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var vp := _p(e.vp)
	var c := _col(e.c, k)
	var dark := _col(e.dark, k)
	var n := int(e.n)
	for i in range(n - 1, -1, -1):
		var s := pow(0.86, i)
		var half := size.x * 0.62 * s
		var bottom := lerpf(vp.y, size.y * 1.05, s)
		var top := lerpf(vp.y, -size.y * 0.15, s)
		var leg := maxf(1.5, size.x * 0.07 * s)
		var shade := c.darkened(0.45 * (1.0 - s))
		for side: float in [-1.0, 1.0]:
			var x := vp.x + side * half
			ci.draw_rect(Rect2(x - leg * 0.5, top, leg, bottom - top), shade)
			ci.draw_rect(Rect2(x - leg * 0.55, bottom - (bottom - top) * 0.1, leg * 1.1, (bottom - top) * 0.1), dark)
			ci.draw_line(Vector2(x + side * leg * 0.5, top), Vector2(x + side * leg * 0.5, bottom), dark.lerp(shade, 0.4), maxf(1.0, leg * 0.08), true)
		ci.draw_rect(Rect2(vp.x - half - leg, top, half * 2.0 + leg * 2.0, leg * 0.7), dark)
		ci.draw_rect(Rect2(vp.x - half - leg * 0.4, top + leg * 1.4, half * 2.0 + leg * 0.8, leg * 0.5), shade)


## The golden pavilion: three storeys (the lowest white and dark wood), snowy roofs, a phoenix.
func _pavilion(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var cx := float(e.x) * size.x
	var base := float(e.y) * size.y
	var w := float(e.w) * size.x
	var gold := _col(e.c, k)
	var roof := _col(e.roof, k)
	var snow := _col(e.snow, k)
	var storey := w * 0.2
	var y := base
	var spec := [[1.0, Color(0.93, 0.92, 0.88, k)], [0.9, gold], [0.56, gold]]
	for i in 3:
		var sw: float = w * spec[i][0] * 0.78
		var face: Color = spec[i][1]
		ci.draw_rect(Rect2(cx - sw * 0.5, y - storey, sw, storey), face)
		var bays := 7 - i * 2
		for j in bays + 1:
			var x := cx - sw * 0.5 + sw * j / bays
			ci.draw_line(Vector2(x, y - storey), Vector2(x, y), roof if i == 0 else face.darkened(0.3), maxf(1.0, w * 0.006), true)
		y -= storey
		var rw: float = w * spec[i][0] * (1.02 if i < 2 else 0.8)
		_roof(ci, cx, y, rw, storey * 0.34, roof)
		_roof(ci, cx, y - storey * 0.2, rw * 0.92, storey * 0.2, snow)
		y -= storey * 0.55
	ci.draw_rect(Rect2(cx - w * 0.012, y - storey * 0.5, w * 0.024, storey * 0.5), gold)
	_shape(ci, PackedVector2Array([Vector2(cx, y - storey * 0.8), Vector2(cx + w * 0.05, y - storey * 0.5),
		Vector2(cx, y - storey * 0.45), Vector2(cx - w * 0.04, y - storey * 0.6)]), gold)


## A branch reaching in from a corner, with blossom (or snow) clusters along it.
func _branch(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var rng := _rng(e)
	var from := _p(e.from)
	var to := _p(e.to)
	var c := _col(e.c, k)
	var blooms: Array = e.bloom
	var points := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		points.append(from.lerp(to, t) + Vector2(0, sin(t * PI * 1.5) * size.y * 0.025))
	for i in points.size() - 1:
		var t := float(i) / (points.size() - 1)
		ci.draw_line(points[i], points[i + 1], c, lerpf(size.y * 0.012, 2.0, t), true)
	for i in 7:
		var at := points[rng.randi_range(2, points.size() - 2)]
		var tip := at + Vector2(rng.randf_range(-1.0, 1.0) * size.x * 0.08, rng.randf_range(0.02, 0.09) * size.y)
		ci.draw_line(at, tip, c, 2.5, true)
		points.append(tip)
	for i in 70:
		var at := points[rng.randi() % points.size()]
		var off := Vector2.from_angle(rng.randf() * TAU) * rng.randf() * size.y * 0.03
		ci.draw_circle(at + off, size.y * rng.randf_range(0.006, 0.013), _col(blooms[rng.randi() % blooms.size()], k), true, -1.0, true)
