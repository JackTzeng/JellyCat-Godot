extends PanelContainer

const VIEWPORT_REFERENCE := Vector2(1672.0, 941.0)
const ICON_COLORS := [Color("#4c9b62"), Color("#5987bb"), Color("#d69b47"), Color("#55a57c"), Color("#888f9d"), Color("#dfaa72"), Color("#f0d36a"), Color("#bd7a56")]
@onready var coin_label: Label = %ShopCoinLabel
@onready var status_label: Label = %ShopStatusLabel
@onready var card_grid: GridContainer = %ShopCardGrid
var cards: Dictionary = {}

static func button_min_height_for(window_size: Vector2, dpi: float) -> float:
	var scale_x := window_size.x / VIEWPORT_REFERENCE.x
	var scale_y := window_size.y / VIEWPORT_REFERENCE.y
	var canvas_scale := minf(scale_x, scale_y)
	var safe_scale := maxf(canvas_scale, 0.001)
	return (48.0 * maxf(dpi, 1.0) / 160.0) / safe_scale

func _ready() -> void:
	GameState.state_changed.connect(refresh)
	%CloseShopButton.pressed.connect(_on_close_pressed)
	_build_cards()
	refresh()

func _build_cards() -> void:
	for child in card_grid.get_children():
		child.queue_free()
	cards.clear()
	var item_ids := _listed_item_ids()
	for index in item_ids.size():
		var item_id: String = item_ids[index]
		var item: Dictionary = GameApp.get_table("items").get(item_id, {})
		var is_decor: bool = item.get("type", "") == "decor"
		var card := PanelContainer.new()
		card.name = "Card_" + item_id
		card.custom_minimum_size = Vector2(0, 260)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 8)
		card.add_child(column)
		var icon: Control
		if is_decor:
			var texture_icon := TextureRect.new()
			texture_icon.name = "Icon"
			texture_icon.custom_minimum_size = Vector2(64, 64)
			texture_icon.texture = load(_decor_icon_path(item_id)) as Texture2D
			texture_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			texture_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			texture_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			texture_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon = texture_icon
		elif item_id == "partner_egg_jellycat":
			var texture_icon := TextureRect.new()
			texture_icon.name = "Icon"
			texture_icon.custom_minimum_size = Vector2(64, 64)
			texture_icon.texture = load("res://assets/eggs/egg_idle_v2_64.png") as Texture2D
			texture_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			texture_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			texture_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			texture_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon = texture_icon
		else:
			var placeholder := ColorRect.new()
			placeholder.name = "Icon"
			placeholder.custom_minimum_size = Vector2(56, 56)
			placeholder.color = ICON_COLORS[index % ICON_COLORS.size()]
			placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon = placeholder
		column.add_child(icon)
		if not is_decor and item_id != "partner_egg_jellycat":
			var initial := Label.new()
			initial.text = _initial_for(item_id)
			initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			initial.add_theme_font_size_override("font_size", 28)
			icon.add_child(initial)
			initial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var name_label := Label.new()
		name_label.name = "ItemName"
		name_label.text = _localized_item_name(item_id)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.clip_text = false
		name_label.custom_minimum_size.y = 48
		column.add_child(name_label)
		var detail := Label.new()
		detail.name = "ItemDetail"
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.clip_text = false
		detail.custom_minimum_size.y = 36
		column.add_child(detail)
		var state := Label.new()
		state.name = "ItemState"
		state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		state.clip_text = false
		state.custom_minimum_size.y = 32
		column.add_child(state)
		var button := Button.new()
		button.name = "BuyButton"
		button.custom_minimum_size = Vector2(0, button_min_height_for(DisplayServer.window_get_size(), DisplayServer.screen_get_dpi()))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_buy.bind(item_id))
		column.add_child(button)
		card_grid.add_child(card)
		cards[item_id] = {"name": name_label, "detail": detail, "state": state, "button": button}

func _listed_item_ids() -> Array[String]:
	var listed: Array[String] = []
	for item_id in GameApp.get_table("items"):
		var item: Dictionary = GameApp.get_table("items")[item_id]
		if item.get("shop_listed", false) and item.get("type", "") != "cookie":
			listed.append(str(item_id))
	listed.sort_custom(func(a: String, b: String) -> bool:
		var order_a: int = int(GameApp.get_table("items")[a].get("shop_order", 2147483647))
		var order_b: int = int(GameApp.get_table("items")[b].get("shop_order", 2147483647))
		return order_a < order_b if order_a != order_b else a < b
	)
	return listed

func refresh() -> void:
	if not is_inside_tree() or not is_node_ready():
		return
	var item_ids := _listed_item_ids()
	var card_ids: Array[String] = []
	for existing_id in cards:
		card_ids.append(str(existing_id))
	card_ids.sort()
	var expected_ids := item_ids.duplicate()
	expected_ids.sort()
	if card_ids != expected_ids:
		_build_cards()
	coin_label.text = "泡泡幣：%d" % GameState.get_currency("bubble_coin")
	var minimum_height := button_min_height_for(DisplayServer.window_get_size(), DisplayServer.screen_get_dpi())
	for item_id in cards.keys():
		if not item_ids.has(item_id):
			cards.erase(item_id)
	for item_id in item_ids:
		var parts: Dictionary = cards[item_id]
		var button: Button = parts.button
		button.custom_minimum_size.y = minimum_height
		var price := ShopSystem.get_item_price(item_id)
		var item: Dictionary = GameApp.get_table("items").get(item_id, {})
		var owned: bool = item.get("type", "") == "decor" and ShopSystem.is_decor_owned(item_id)
		var unlimited: bool = item_id == "food_basic"
		var at_limit: bool = item_id == "partner_egg_jellycat" and ShopSystem.is_partner_egg_at_limit()
		var affordable: bool = unlimited or (price >= 0 and ShopSystem.can_buy(item_id))
		parts.detail.text = "無限供應" if unlimited else "價格：%d 泡泡幣" % price
		var state_text := "已擁有" if owned else ("水族箱已滿" if at_limit else ("幣不足" if not affordable and not unlimited else "可購買"))
		parts.state.text = "狀態：" + state_text
		button.text = "無限供應" if unlimited else ("已擁有" if owned else ("水族箱已滿" if at_limit else ("幣不足" if not affordable else "購買")))
		button.disabled = unlimited or owned or at_limit or not affordable
		button.tooltip_text = button.text
	# Preserve named nodes used by G1 and Android scene acceptance assertions.
	%FoodInfoLabel.text = "%s｜∞｜飼料無限" % _localized_item_name("food_basic")
	%MedicineInfoLabel.text = _localized_item_name("medicine_basic")
	%PartnerEggInfoLabel.text = _localized_item_name("partner_egg_jellycat")
	%BuyFoodButton.text = "無限供應"
	%BuyFoodButton.disabled = true
	%BuyMedicineButton.text = "購買" if ShopSystem.can_buy("medicine_basic") else "幣不足"
	%BuyMedicineButton.disabled = not ShopSystem.can_buy("medicine_basic")
	%BuyPartnerEggButton.text = "水族箱已滿" if ShopSystem.is_partner_egg_at_limit() else ("購買" if ShopSystem.can_buy("partner_egg_jellycat") else "幣不足")
	%BuyPartnerEggButton.disabled = not ShopSystem.can_buy("partner_egg_jellycat")

func _decor_icon_path(item_id: String) -> String:
	match item_id:
		"decor_seaweed": return "res://assets/decor/decor_seaweed_icon_v3_32x32.png"
		"decor_stone": return "res://assets/decor/decor_stone_icon_v1_32x32.png"
		"decor_shell": return "res://assets/decor/decor_shell_icon_v1_32x32.png"
		"decor_lamp": return "res://assets/decor/decor_lamp_icon_v1_32x32.png"
		"decor_castle": return "res://assets/decor/decor_castle_icon_v1_32x32.png"
		_: return ""

func _buy(item_id: String) -> void:
	if ShopSystem.buy_item(item_id):
		status_label.text = "已購買%s。" % _localized_item_name(item_id)
	else:
		status_label.text = "無法購買%s。" % _localized_item_name(item_id)
	refresh()

func _on_close_pressed() -> void:
	visible = false

func _initial_for(item_id: String) -> String:
	var value := _localized_item_name(item_id)
	return value.substr(0, 1)

func _localized_item_name(item_id: String) -> String:
	match item_id:
		"medicine_basic": return "藥水"
		"food_basic": return "飼料"
		"partner_egg_jellycat": return "水母喵夥伴蛋"
		"decor_seaweed": return "海草叢"
		"decor_stone": return "小石頭"
		"decor_shell": return "貝殼"
		"decor_lamp": return "小燈"
		"decor_castle": return "小城堡"
		_: return item_id
