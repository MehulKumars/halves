extends Modal
## One more use of a booster (hint, undo, shuffle) once the level's free use is spent: pay coins.
## Opened by the game screen; closes with "coins" or null. Coins are earned by play (stars,
## combos, lucky pairs, the daily), so a player who can't afford it is told how to earn more.


func _ready() -> void:
	super._ready()
	%CoinsButton.pressed.connect(close.bind("coins"))
	%CancelButton.pressed.connect(close.bind(null))


func setup(_booster: String, title: String, icon: Texture2D, price: int, coins: int) -> void:
	%Title.text = title
	%Icon.texture = icon
	%Icon.modulate = get_theme_color(&"gold", &"Tokens")
	var affordable := coins >= price
	%Balance.text = "You have %d coins" % coins if affordable else \
			"You have %d coins. Clear levels and the daily puzzle to earn more." % coins
	%CoinsButton.text = "Use for %d coins" % price
	%CoinsButton.disabled = not affordable
	%CoinsButton.theme_type_variation = &"AccentButton" if affordable else &"Button"
