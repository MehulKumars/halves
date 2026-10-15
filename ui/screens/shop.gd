extends Screen
## Shop: a "Remove ads" purchase, coin packs, and free coins for a rewarded video.
## Purchases go through Services.iap (a mock until Play Billing is added, see docs/SERVICES.md).
## Prices below are placeholders: real ones come from the store in the player's currency.

const NO_ADS_ID: String = "remove_ads"
const FREE_COINS: int = 50
## Six packs fill the grid evenly in 2 columns (phones) and 3 (tablets).
const PACKS: Array[Dictionary] = [
	{"id": "coins_1", "coins": 500, "price": "$0.99", "badge": ""},
	{"id": "coins_2", "coins": 1200, "price": "$1.99", "badge": "+20%"},
	{"id": "coins_3", "coins": 2500, "price": "$3.99", "badge": "Popular"},
	{"id": "coins_4", "coins": 6500, "price": "$7.99", "badge": "+60%"},
	{"id": "coins_5", "coins": 14000, "price": "$14.99", "badge": ""},
	{"id": "coins_6", "coins": 32000, "price": "$29.99", "badge": "Best value"},
]


func _ready() -> void:
	back_scene = Screens.MAIN_MENU
	%BackButton.pressed.connect(on_back)
	%Coins.value = Progress.coins()
	%NoAdsIcon.modulate = get_theme_color(&"danger", &"Tokens")
	%FreeIcon.modulate = get_theme_color(&"gold", &"Tokens")
	%NoAdsBuy.pressed.connect(_buy_no_ads)
	%FreeButton.pressed.connect(_watch_for_coins)
	%FreeButton.disabled = not Services.ads.is_rewarded_ready("shop_free_coins")
	_refresh_no_ads()
	for pack in PACKS:
		%Packs.add_child(_pack_card(pack))


func _pack_card(pack: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"HighlightPanel" if pack.badge == "Best value" else &"TilePanel"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	card.add_child(box)
	var badge_row := HBoxContainer.new()
	badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	badge_row.custom_minimum_size.y = 36
	box.add_child(badge_row)
	if not String(pack.badge).is_empty():
		var badge := PanelContainer.new()
		badge.theme_type_variation = &"BadgePanel"
		var badge_text := Label.new()
		badge_text.theme_type_variation = &"BadgeLabel"
		badge_text.text = String(pack.badge).to_upper()
		badge.add_child(badge_text)
		badge_row.add_child(badge)
	var icon := TextureRect.new()
	icon.texture = Icons.COIN
	icon.modulate = get_theme_color(&"gold", &"Tokens")
	icon.custom_minimum_size = Vector2(0, 72)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(icon)
	var amount := Label.new()
	amount.theme_type_variation = &"ValueLabel"
	amount.text = CurrencyPill.format_number(int(pack.coins))
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(amount)
	var buy := Button.new()
	buy.theme_type_variation = &"AccentButton"
	buy.text = pack.price
	buy.pressed.connect(_buy_pack.bind(pack))
	box.add_child(buy)
	return card


func _buy_pack(pack: Dictionary) -> void:
	Services.iap.purchase(pack.id)
	var result: Array = await Services.iap.purchase_finished
	if result[1]:
		Progress.add_coins(int(pack.coins))
		%Coins.set_value(Progress.coins())
		Haptics.success()
		UI.toast("+%s coins" % CurrencyPill.format_number(int(pack.coins)), Icons.COIN)


func _buy_no_ads() -> void:
	Services.iap.purchase(NO_ADS_ID)
	var result: Array = await Services.iap.purchase_finished
	if result[1]:
		Progress.set_owned(NO_ADS_ID)
		Haptics.success()
		UI.toast("Ads removed. Thank you!", Icons.CHECK_CIRCLE)
		_refresh_no_ads()


func _refresh_no_ads() -> void:
	var owned := Progress.owns(NO_ADS_ID)
	%NoAdsBuy.disabled = owned
	%NoAdsBuy.text = "Owned" if owned else "$2.99"


## Rewarded video: the player chooses it, and the button says what it gives.
func _watch_for_coins() -> void:
	%FreeButton.disabled = true
	Services.ads.show_rewarded("shop_free_coins")
	var result: Array = await Services.ads.rewarded_finished
	if result[1]:
		Progress.add_coins(FREE_COINS)
		%Coins.set_value(Progress.coins())
		UI.toast("+%d coins" % FREE_COINS, Icons.COIN)
	%FreeButton.disabled = not Services.ads.is_rewarded_ready("shop_free_coins")
