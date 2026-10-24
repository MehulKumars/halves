class_name HalvesPalette
extends RefCounted
## The Halves art palette from the concept sketch (ivory tiles, cobalt, terracotta, teal, sand).
## Used only by the board art in game/halves/; UI colours come from the theme's Tokens instead.
## Each shape has one colour, but colour is never the only cue: the shapes differ too.

const IVORY: Color = Color("#FBF8F3")
const COBALT: Color = Color("#1F3A5F")
const TERRACOTTA: Color = Color("#A23A24")
const TEAL: Color = Color("#2A8C80")
const SAND: Color = Color("#F2CC8F")
## The dark edge under every tile face.
const SIDE: Color = Color("#142A45")
## Feature overlays: mist waves, frost wash and rim, gold coin badges.
const MIST: Color = Color("#8FA6BF")
const ICE: Color = Color("#BFE3F5")
const ICE_EDGE: Color = Color("#E8F7FF")
const GOLD: Color = Color("#E8B84A")
const GOLD_DARK: Color = Color("#A9792A")
## Multiplied over a tile that can't be picked yet (a tint, not transparency, so nothing shows through).
const BLOCKED_TINT: Color = Color(0.7, 0.72, 0.76)


## (v3) Crest inks, one per family: traditional Japanese dye colours, all at least 4.5:1 on IVORY.
const FAMILY_INKS: Dictionary[StringName, Color] = {
	&"blossoms": Color("#A3324A"),  # beni, crimson
	&"tomoe": Color("#B03E26"),     # shu, vermilion
	&"sky": Color("#8A5A0E"),       # kincha, golden brown
	&"waves": Color("#1D4A73"),     # ai, indigo
	&"lattice": Color("#2E2A28"),   # sumi, ink
	&"leaves": Color("#3F6B2E"),    # moss
	&"things": Color("#5E4387"),    # murasaki, purple
	&"wings": Color("#1C6B64"),     # aotake, blue-green
}


## The colour a face is drawn in: its shape's colour (v2) or its family's ink (crests).
static func face_color(face: int) -> Color:
	if HalvesFace.is_crest(face):
		return family_color(HalvesFace.family(face))
	return shape_color(HalvesFace.shape(face))


static func family_color(family: StringName) -> Color:
	return FAMILY_INKS.get(family, SIDE)


static func shape_color(shape: int) -> Color:
	match shape:
		HalvesFace.Shape.CIRCLE:
			return COBALT
		HalvesFace.Shape.TRIANGLE:
			return TERRACOTTA
	return TEAL
