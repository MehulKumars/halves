extends Modal
## One more use of a booster (hint, undo, shuffle) once the level's free use is spent: pay coins,
## or watch a rewarded video the player chooses. Opened by the game screen; closes with "coins",
## "video" (only after the ad granted its reward) or null. The button says what the video gives.

var _placement: String = ""


func _ready() -> void:
	super._ready()
	%CoinsButton.pressed.connect(close.bind("coins"))
	%VideoButton.pressed.connect(_on_video)
	%CancelButton.pressed.connect(close.bind(null))


func setup(booster: String, title: String, icon: Texture2D, price: int, coins: int) -> void:
	_placement = booster
	%Title.text = title
	%Icon.texture = icon
	%Icon.modulate = get_theme_color(&"gold", &"Tokens")
	%Balance.text = "You have %d coins" % coins
	var affordable := coins >= price
	%CoinsButton.text = "Use for %d coins" % price
	%CoinsButton.disabled = not affordable
	%CoinsButton.theme_type_variation = &"AccentButton" if affordable else &"Button"
	%VideoButton.visible = Services.ads.is_rewarded_ready(booster)
	%VideoButton.theme_type_variation = &"Button" if affordable else &"AccentButton"


func _on_video() -> void:
	%VideoButton.disabled = true
	Services.ads.show_rewarded(_placement)
	var result: Array = await Services.ads.rewarded_finished
	if result[1]:
		close("video")
	else:
		%VideoButton.disabled = false
		UI.toast("No reward this time")
