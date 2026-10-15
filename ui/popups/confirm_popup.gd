extends Modal
## Yes/no question, opened by UI.confirm(). Closes with true when confirmed, false or null
## otherwise. Destructive questions (reset, quit) colour the confirm button as danger.


func _ready() -> void:
	super._ready()
	%ConfirmButton.pressed.connect(close.bind(true))
	%CancelButton.pressed.connect(close.bind(false))


func setup(title: String, message: String, confirm_text: String = "OK", destructive: bool = false) -> void:
	%Title.text = title
	%Message.text = message
	%Message.visible = not message.is_empty()
	%ConfirmButton.text = confirm_text
	%ConfirmButton.theme_type_variation = &"DangerButton" if destructive else &"AccentButton"
