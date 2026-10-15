extends Modal
## End-of-level popup. Call show_win(level, stars, coins) or show_lose(level) after opening.
## Closes with "next", "retry", "home" or "continue" (lose only, after a rewarded ad the player
## chose to watch). The game screen decides about interstitials when this opens (AdPolicy).


func _ready() -> void:
	super._ready()
	%NextButton.pressed.connect(close.bind("next"))
	%RetryButton.pressed.connect(close.bind("retry"))
	%HomeButton.pressed.connect(close.bind("home"))
	%ContinueButton.pressed.connect(_on_continue)


func show_win(level: int, stars: int, coins: int) -> void:
	%Headline.text = "Level %d complete!" % level
	%Message.text = ["Done!", "Nice!", "Great!", "Perfect!"][clampi(stars, 0, 3)]
	%ContinueButton.hide()
	%NextButton.show()
	%Stars.show()
	%RewardRow.show()
	%Reward.value = 0
	Haptics.big()
	%Stars.reveal(stars, 0.3)
	await get_tree().create_timer(0.3 * stars + 0.2, true, false, true).timeout
	if is_inside_tree():
		%Reward.set_value(coins)


func show_lose(level: int) -> void:
	%Headline.text = "Out of moves"
	%Message.text = "Level %d. Watch a short video for 5 more moves, or try again." % level
	%Stars.hide()
	%RewardRow.hide()
	%NextButton.hide()
	%ContinueButton.visible = Services.ads.is_rewarded_ready("continue")
	%RetryButton.theme_type_variation = &"AccentButton"


## Rewarded ads are always the player's choice and say what they give (Play policy).
func _on_continue() -> void:
	%ContinueButton.disabled = true
	Services.ads.show_rewarded("continue")
	var result: Array = await Services.ads.rewarded_finished
	if result[1]:
		close("continue")
	else:
		%ContinueButton.disabled = false
		UI.toast("No reward this time")
