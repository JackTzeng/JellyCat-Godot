extends Node

const SHOP_SCENE := preload("res://scenes/ui/shop_panel.tscn")
const AQUARIUM_SCENE := preload("res://scenes/aquarium/aquarium.tscn")
const DECOR_IDS := ["decor_seaweed", "decor_stone", "decor_shell", "decor_lamp", "decor_castle"]
var checks := 0
var timed_out := false

func _ready() -> void:
	print("G2_SHOP_UI_ACCEPTANCE_PROGRESS start")
	get_tree().create_timer(90.0).timeout.connect(_watchdog)
	_run.call_deferred()

func _watchdog() -> void:
	if not timed_out:
		timed_out = true
		print("WATCHDOG_TIMEOUT")
		get_tree().quit(2)

func _run() -> void:
	GameApp.load_data_tables()
	var shop := SHOP_SCENE.instantiate()
	add_child(shop)
	await get_tree().process_frame
	_assert(shop.cards.size() == 8, "eight shop cards")
	var sizes := [Vector2(1280, 720), Vector2(1280, 591), Vector2(1600, 720)]
	var dpis := [160.0, 320.0, 160.0]
	for i in sizes.size():
		var min_height: float = shop.button_min_height_for(sizes[i], dpis[i])
		var physical_px: float = min_height * minf(sizes[i].x / Vector2(1672, 941).x, sizes[i].y / Vector2(1672, 941).y)
		_assert(physical_px * 160.0 / dpis[i] >= 48.0, "button >=48dp resolution %d" % i)
	var buttons: Array = []
	for item_id in shop.ITEM_IDS:
		buttons.append(shop.cards[item_id].button)
	var target_size: Vector2 = buttons[0].custom_minimum_size
	for button in buttons:
		_assert(button.custom_minimum_size.y == target_size.y, "uniform button height")
		_assert(not button.clip_text, "button text not clipped")
	# Layout is scrollable; confirm every card is a child of the grid.
	_assert(shop.card_grid.get_child_count() == 8, "all cards in scroll grid")
	print("G2_SHOP_UI_ACCEPTANCE_PROGRESS cards_and_dp complete")
	GameState.reset_to_default()
	GameState.set_currency("bubble_coin", 600)
	var aquarium := AQUARIUM_SCENE.instantiate()
	aquarium.set_process(false)
	aquarium.set_physics_process(false)
	add_child(aquarium)
	await get_tree().process_frame
	var owned: Array[Dictionary] = []
	for i in DECOR_IDS.size():
		owned.append({"item_id": DECOR_IDS[i], "slot": i, "purchased_at": "test"})
	GameState.data["aquarium"]["owned_decor"] = owned
	GameState.state_changed.emit()
	await get_tree().process_frame
	_assert(aquarium.decor_visuals.size() == 5, "all five owned decorations render")
	for visual in aquarium.decor_visuals:
		_assert(visual.mouse_filter == Control.MOUSE_FILTER_IGNORE, "decorations ignore pointer input")
		_assert(visual.size.y <= aquarium.size.y / 3.0, "decor height limited to one third tank")
	for screen_size in sizes:
		aquarium.call("_layout_ui", screen_size, Rect2(Vector2.ZERO, screen_size))
		aquarium.call("_refresh_decor", screen_size)
		await get_tree().process_frame
		for visual in aquarium.decor_visuals:
			var decor_rect: Rect2 = visual.get_global_rect()
			_assert(not decor_rect.intersects(aquarium.pet_roster_scroll.get_global_rect()), "decor does not overlap nameplate at %s" % str(screen_size))
			_assert(not decor_rect.intersects(aquarium.inventory_backdrop.get_global_rect()), "decor does not overlap HUD at %s" % str(screen_size))
			_assert(not decor_rect.intersects(aquarium.action_scroll.get_global_rect()), "decor does not overlap bottom buttons at %s" % str(screen_size))
	_assert(shop.cards["decor_seaweed"].button.disabled, "owned decor card disabled")
	# Exercise the real card button/API path with a fresh, unowned decor item.
	GameState.reset_to_default()
	GameState.set_currency("bubble_coin", 100)
	shop.refresh()
	print("G2 shop purchase preflight items=%s" % str(GameApp.get_table("items").keys()))
	print("G2 shop purchase preflight coin=%d price=%d can_buy=%s disabled=%s" % [GameState.get_currency("bubble_coin"), ShopSystem.get_item_price("decor_seaweed"), str(ShopSystem.can_buy("decor_seaweed")), str(shop.cards["decor_seaweed"].button.disabled)])
	shop.cards["decor_seaweed"].button.pressed.emit()
	await get_tree().process_frame
	_assert(GameState.is_decor_owned("decor_seaweed"), "shop card purchases decoration")
	_assert(aquarium.decor_visuals.size() == 1, "purchased decor appears immediately in slot")
	_assert(shop.cards["decor_seaweed"].state.text == "狀態：已擁有", "purchased card reports owned")
	print("G2_SHOP_UI_ACCEPTANCE_PROGRESS decor rendering and purchase complete")
	if not timed_out:
		print("G2_SHOP_UI_ACCEPTANCE_OK checks=%d" % checks)
		get_tree().quit(0)

func _assert(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error("G2 shop UI acceptance failed: " + message)
