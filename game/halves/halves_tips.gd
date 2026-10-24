class_name HalvesTips
extends RefCounted
## The tip cards that teach each rule once, on the level that brings it in (HalvesLevelData.tip),
## plus a few shown on events (first stuck board, first par). Each has a tiny board drawn with the
## real tile art. Shown by ui/popups/tip_popup.gd; "How to play" pages through all of them.

## In play order. tiles: [x, y, z, face] in half-units; rings: {tile: "selected" | "hint" | "mistake"}.
const TIPS: Dictionary = {
	"pair": {"title": "Make whole shapes",
		"text": "Tap a free tile, then the other half of the same shape. The two halves snap into one.",
		"tiles": [[0, 0, 0, "circle:v:-:a"], [4, 0, 0, "circle:v:-:b"]], "rings": {0: "selected", 1: "hint"}},
	"layers": {"title": "Tiles stack up",
		"text": "A tile is free when nothing lies on it. Covered tiles look darker: clear the top first.",
		"tiles": [[0, 0, 0, "tri:v:-:a"], [2, 0, 0, "square:v:-:b"], [1, 0, 1, "circle:v:-:a"]], "rings": {2: "hint"}},
	"sides": {"title": "Open ends",
		"text": "In a row, a tile needs a free left or right side. Work rows in from the ends.",
		"tiles": [[0, 0, 0, "circle:v:-:a"], [2, 0, 0, "tri:v:-:a"], [4, 0, 0, "circle:v:-:b"]], "rings": {0: "hint", 2: "hint"}},
	"decoy": {"title": "Never match twins",
		"text": "Two left halves never make a whole. A wrong pair is a slip: a few are free, more cost a star.",
		"tiles": [[0, 0, 0, "circle:v:-:a"], [4, 0, 0, "circle:v:-:a"]], "rings": {0: "mistake", 1: "mistake"}},
	"trap": {"title": "Look underneath",
		"text": "A half lying on its own mate can never meet it. Pair the top one first. Getting stuck is a slip.",
		"tiles": [[0, 0, 0, "circle:v:-:b"], [6, 0, 0, "circle:v:-:a"], [10, 0, 0, "circle:v:-:b"], [0, 0, 1, "circle:v:-:a"]],
		"rings": {3: "hint", 2: "hint"}},
	"cut_h": {"title": "Top meets bottom",
		"text": "Some shapes are cut across. A top half matches the bottom half of the same shape.",
		"tiles": [[0, 0, 0, "circle:h:-:a"], [4, 0, 0, "circle:h:-:b"]], "rings": {0: "selected", 1: "hint"}},
	"diamond": {"title": "Square or diamond?",
		"text": "Squares and diamonds share a colour. Look at the corners before you tap.",
		"tiles": [[0, 0, 0, "square:v:-:a"], [4, 0, 0, "diamond:v:-:b"], [8, 0, 0, "square:v:-:b"]], "rings": {0: "selected", 2: "hint"}},
	"dot": {"title": "Marks matter",
		"text": "A dot only meets a dot. Halves with different marks don't fit.",
		"tiles": [[0, 0, 0, "tri:v:dot:a"], [4, 0, 0, "tri:v:-:b"], [8, 0, 0, "tri:v:dot:b"]], "rings": {0: "selected", 2: "hint"}},
	"line": {"title": "Lines too",
		"text": "A line meets a line, the same way a dot meets a dot.",
		"tiles": [[0, 0, 0, "square:v:line:a"], [4, 0, 0, "square:v:line:b"]], "rings": {0: "selected", 1: "hint"}},
	"gold": {"title": "Gold tiles",
		"text": "Clear a gold tile for 5 bonus coins at the end of the level.",
		"tiles": [[0, 0, 0, "tri:v:-:a"], [4, 0, 0, "tri:v:-:b"]], "features": {"gold": [0, 1]}},
	"mist": {"title": "Mist",
		"text": "Misty tiles hide their face until they are free. Plan for a surprise.",
		"tiles": [[0, 0, 0, "circle:v:-:a"], [4, 0, 0, "square:v:-:b"], [0, 0, 1, "square:v:-:a"]],
		"features": {"mist": [0]}, "rings": {2: "hint", 1: "hint"}},
	"lock": {"title": "Locks and keys",
		"text": "A padlocked tile opens once every key tile is cleared. Find the keys first.",
		"tiles": [[0, 0, 0, "circle:v:-:a"], [4, 0, 0, "circle:v:-:b"], [8, 0, 0, "tri:v:-:a"]],
		"features": {"locks": [{"keys": [0, 1], "locked": [2]}]}, "rings": {0: "hint", 1: "hint"}},
	"frost": {"title": "Frost",
		"text": "A frozen tile thaws when a tile beside it, above or below it, or on top of it is cleared.",
		"tiles": [[0, 0, 0, "square:v:-:a"], [2, 0, 0, "circle:v:-:a"], [6, 0, 0, "circle:v:-:b"]],
		"features": {"frost": [0]}, "rings": {1: "hint", 2: "hint"}},
	"stuck": {"title": "Stuck?",
		"text": "No pairs left: undo your last pairs, or shuffle. A shuffle out of a dead end is a slip.",
		"tiles": [[0, 0, 0, "circle:v:-:b"], [0, 0, 1, "circle:v:-:a"]]},
	"swift": {"title": "Beat the clock",
		"text": "Clear a level within its par time for the Swift medal. The clock only runs while you play.",
		"tiles": [[0, 0, 0, "diamond:v:-:a"], [4, 0, 0, "diamond:v:-:b"]], "rings": {0: "selected", 1: "hint"}},
	# v3: crests and the new mechanics.
	"lookalike": {"title": "Look-alikes",
		"text": "Some crests look alike. Count the petals, look for a ring: only the same crest fits.",
		"tiles": [[0, 0, 0, "sakura:v:a"], [4, 0, 0, "ume:v:b"], [8, 0, 0, "sakura:v:b"]], "rings": {0: "selected", 2: "hint"}},
	"gold_pair": {"title": "The gold pair",
		"text": "Clear the two gold tiles to earn a mend.",
		"tiles": [[0, 0, 0, "kin:v:a"], [4, 0, 0, "kin:v:b"]], "rings": {0: "selected", 1: "hint"}},
	"mend": {"title": "Mend",
		"text": "Tap Mend, then a free tile: its other half flies out of the stack to meet it, wherever it is.",
		"tiles": [[0, 0, 0, "kikyo:v:a"], [4, 0, 0, "kikyo:v:b"], [4, 0, 1, "uzu:v:a"]], "rings": {0: "selected", 1: "hint"}},
	"turned": {"title": "Turned halves",
		"text": "Some halves lie turned on their side. It is still the same crest: turn it in your head.",
		"tiles": [[0, 0, 0, "hoshi5:v:a"], [4, 0, 0, "hoshi5:v:b"]], "features": {"turned": [1]}, "rings": {0: "selected", 1: "hint"}},
	"lucky": {"title": "Lucky tiles",
		"text": "A glowing tile is lucky: clear it within three pairs for bonus coins.",
		"tiles": [[0, 0, 0, "ogi:v:a"], [4, 0, 0, "ogi:v:b"]], "features": {"lucky": [0]}, "rings": {0: "hint", 1: "hint"}},
}


static func has_tip(id: String) -> bool:
	return TIPS.has(id)


static func ids() -> Array:
	return TIPS.keys()


static func get_tip(id: String) -> Dictionary:
	return TIPS.get(id, {})


## A tiny level holding the tip's tiles, for a HalvesBoardView to draw.
static func level_data(id: String) -> HalvesLevelData:
	var tip := get_tip(id)
	return HalvesLevelData.from_dict({"level": 0, "tiles": tip.get("tiles", []), "features": tip.get("features", {})})
