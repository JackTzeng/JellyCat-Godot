extends PanelContainer

@onready var coin_label: Label = %ShopCoinLabel
@onready var status_label: Label = %ShopStatusLabel

func _ready() -> void:
	GameState.state_changed.connect(refresh)
	%BuyFoodButton.pressed.connect(_on_buy_food_pressed)
	%BuyMedicineButton.pressed.connect(_on_buy_medicine_pressed)
	%CloseShopButton.pressed.connect(_on_close_pressed)
	refresh()


func refresh() -> void:
	coin_label.text = "泡泡幣：%d" % GameState.get_currency("bubble_coin")
	%FoodInfoLabel.text = _item_line("food_basic")
	%BuyFoodButton.disabled = true
	%BuyFoodButton.text = "無限供應"
	%MedicineInfoLabel.text = _item_line("medicine_basic")


func _on_buy_food_pressed() -> void:
	_buy("food_basic")


func _on_buy_medicine_pressed() -> void:
	_buy("medicine_basic")


func _on_close_pressed() -> void:
	visible = false


func _buy(item_id: String) -> void:
	if ShopSystem.buy_item(item_id):
		status_label.text = "已購買%s。" % _localized_item_name(item_id)
	else:
		status_label.text = "無法購買%s。" % _localized_item_name(item_id)
	refresh()


func _item_line(item_id: String) -> String:
	if item_id == "food_basic":
		return "飼料｜∞｜飼料無限"
	return "%s｜價格 %d｜持有 %d" % [
		_localized_item_name(item_id),
		ShopSystem.get_item_price(item_id),
		GameState.get_inventory_count(item_id)
	]


func _localized_item_name(item_id: String) -> String:
	match item_id:
		"medicine_basic":
			return "藥水"
		"food_basic":
			return "飼料"
		_:
			return "物品"
