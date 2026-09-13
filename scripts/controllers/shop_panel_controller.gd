extends PanelContainer

@onready var coin_label: Label = %ShopCoinLabel
@onready var status_label: Label = %ShopStatusLabel

func _ready() -> void:
	GameState.state_changed.connect(refresh)
	%BuyFoodButton.pressed.connect(_on_buy_food_pressed)
	%BuyCookieButton.pressed.connect(_on_buy_cookie_pressed)
	%BuyMedicineButton.pressed.connect(_on_buy_medicine_pressed)
	%CloseShopButton.pressed.connect(_on_close_pressed)
	refresh()


func refresh() -> void:
	coin_label.text = "Bubble Coin: %d" % GameState.get_currency("bubble_coin")
	%FoodInfoLabel.text = _item_line("food_basic")
	%CookieInfoLabel.text = _item_line("cookie_basic")
	%MedicineInfoLabel.text = _item_line("medicine_basic")


func _on_buy_food_pressed() -> void:
	_buy("food_basic")


func _on_buy_cookie_pressed() -> void:
	_buy("cookie_basic")


func _on_buy_medicine_pressed() -> void:
	_buy("medicine_basic")


func _on_close_pressed() -> void:
	visible = false


func _buy(item_id: String) -> void:
	if ShopSystem.buy_item(item_id):
		status_label.text = "Bought %s." % item_id
	else:
		status_label.text = "Cannot buy %s." % item_id
	refresh()


func _item_line(item_id: String) -> String:
	var item_value: Variant = GameApp.get_table("items").get(item_id, {})
	var item: Dictionary = {}
	if item_value is Dictionary:
		item = item_value as Dictionary
	return "%s | Price %d | Owned %d" % [
		str(item.get("display_name", item_id)),
		ShopSystem.get_item_price(item_id),
		GameState.get_inventory_count(item_id)
	]
