extends Modal
## Seven-day login reward. Today's tile is highlighted, claimed days show a tick, day 7 is a
## gift. Claim adds the coins (Progress.claim_daily) and closes with the amount.
## Missing a whole day restarts at day 1 (see Progress.daily_status).


func _ready() -> void:
	super._ready()
	var status := Progress.daily_status()
	_build_days(status)
	var claim: Button = %ClaimButton
	claim.disabled = not status.can_claim
	claim.text = "Claim %d coins" % status.amount if status.can_claim else "Come back tomorrow"
	claim.pressed.connect(_on_claim)
	%LaterButton.pressed.connect(close.bind(0))


func _build_days(status: Dictionary) -> void:
	var grid: Container = %Days
	var today: int = status.day
	for i in Progress.DAILY_REWARDS.size():
		var day := i + 1
		var is_today := day == today and bool(status.can_claim)
		var claimed: bool = day < today or (day == today and not status.can_claim)
		var tile := PanelContainer.new()
		tile.theme_type_variation = &"HighlightPanel" if is_today else &"TilePanel"
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.modulate.a = 0.55 if claimed else 1.0
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override(&"separation", 4)
		tile.add_child(box)
		var label := Label.new()
		label.text = "Day %d" % day
		label.theme_type_variation = &"CaptionLabel"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(label)
		var icon := TextureRect.new()
		icon.texture = Icons.CHECK_CIRCLE if claimed else (Icons.GIFT if day == 7 else Icons.COIN)
		icon.modulate = get_theme_color(&"positive" if claimed else &"gold", &"Tokens")
		icon.custom_minimum_size = Vector2(64, 64) if day == 7 else Vector2(52, 52)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		box.add_child(icon)
		var amount := Label.new()
		amount.text = str(Progress.DAILY_REWARDS[i])
		amount.theme_type_variation = &"ValueLabel"
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(amount)
		grid.add_child(tile)
		if is_today:
			tile.pivot_offset_ratio = Vector2(0.5, 0.5)
			Juice.pop.call_deferred(tile, 1.08, 0.3)


func _on_claim() -> void:
	var amount := Progress.claim_daily()
	if amount > 0:
		Haptics.success()
		UI.toast("+%d coins" % amount, Icons.COIN)
	close(amount)
