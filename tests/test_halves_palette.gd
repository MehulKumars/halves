extends GutTest
## Crest inks for everyone: each family's ink has at least 3:1 contrast on its tile (WCAG 1.4.11),
## 4.5:1 with Bold tiles on, and the families stay apart under protan, deutan and tritan vision
## (Machado 2009 matrices at full severity, distances in OKLab). Colour is a hint; shapes still differ.

## Linear-RGB simulation matrices, row by row (Machado, Oliveira and Fernandes 2009, severity 1.0).
const SIMULATIONS: Dictionary[String, Array] = {
	"normal": [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0],
	"protan": [0.152286, 1.052583, -0.204868, 0.114503, 0.786281, 0.099216, -0.003882, -0.048116, 1.051998],
	"deutan": [0.367322, 0.860646, -0.227968, 0.280085, 0.672501, 0.047413, -0.011820, 0.042940, 0.968881],
	"tritan": [1.255528, -0.076749, -0.178779, -0.078411, 0.930809, 0.147602, 0.004733, 0.691367, 0.303900],
}
## Smallest OKLab distance between two families' inks: about twice a just-noticeable difference
## (~0.02) for colour-blind vision, more for normal vision.
const MIN_APART_CVD: float = 0.04
const MIN_APART_NORMAL: float = 0.07


func after_each() -> void:
	HalvesShapes.bold = false


func test_each_ink_has_contrast_on_its_tile() -> void:
	for family: StringName in HalvesPalette.FAMILY_INKS:
		var ink: Color = HalvesPalette.FAMILY_INKS[family]
		var ratio := _contrast(ink, _paper(family))
		assert_gte(ratio, 3.0, "%s ink on its tile: %.2f:1" % [family, ratio])


func test_bold_ink_has_text_contrast() -> void:
	HalvesShapes.bold = true
	for family: StringName in HalvesPalette.FAMILY_INKS:
		var pairs := HalvesCrests.pairs_in_family(family)
		assert_false(pairs.is_empty(), "family %s has crests" % family)
		if pairs.is_empty():
			continue
		var face := pairs[0] << 1
		var ratio := _contrast(HalvesShapes.ink(face), HalvesPalette.face_paper(face))
		assert_gte(ratio, 4.5, "%s bold ink: %.2f:1" % [family, ratio])


func test_families_stay_apart_for_colour_blind_players() -> void:
	var families: Array[StringName] = []
	for family: StringName in HalvesPalette.FAMILY_INKS:
		if family != &"gold":  # the gold pair sits on its own gold face
			families.append(family)
	for sim: String in SIMULATIONS:
		var least := MIN_APART_NORMAL if sim == "normal" else MIN_APART_CVD
		for i in families.size():
			for j in range(i + 1, families.size()):
				var a := _oklab(_simulate(HalvesPalette.FAMILY_INKS[families[i]], SIMULATIONS[sim]))
				var b := _oklab(_simulate(HalvesPalette.FAMILY_INKS[families[j]], SIMULATIONS[sim]))
				assert_gte(a.distance_to(b), least, "%s vs %s (%s)" % [families[i], families[j], sim])


func _paper(family: StringName) -> Color:
	return HalvesPalette.GOLD_FACE if family == &"gold" else HalvesPalette.IVORY


## WCAG contrast ratio of two sRGB colours.
func _contrast(a: Color, b: Color) -> float:
	var la := a.srgb_to_linear().get_luminance()
	var lb := b.srgb_to_linear().get_luminance()
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## The colour as seen with the simulation matrix `m`, in linear RGB.
func _simulate(colour: Color, m: Array) -> Vector3:
	var c := colour.srgb_to_linear()
	return Vector3(
		clampf(m[0] * c.r + m[1] * c.g + m[2] * c.b, 0.0, 1.0),
		clampf(m[3] * c.r + m[4] * c.g + m[5] * c.b, 0.0, 1.0),
		clampf(m[6] * c.r + m[7] * c.g + m[8] * c.b, 0.0, 1.0))


## Linear RGB to OKLab (Björn Ottosson, 2020).
func _oklab(rgb: Vector3) -> Vector3:
	var l := pow(0.4122214708 * rgb.x + 0.5363325363 * rgb.y + 0.0514459929 * rgb.z, 1.0 / 3.0)
	var m := pow(0.2119034982 * rgb.x + 0.6806995451 * rgb.y + 0.1073969566 * rgb.z, 1.0 / 3.0)
	var s := pow(0.0883024619 * rgb.x + 0.2817188376 * rgb.y + 0.6299787005 * rgb.z, 1.0 / 3.0)
	return Vector3(0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)
