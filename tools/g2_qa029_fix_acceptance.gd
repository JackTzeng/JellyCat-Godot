extends Node

const SHOP_SCENE := preload("res://scenes/ui/shop_panel.tscn")
const DECOR_IDS := ["decor_seaweed", "decor_stone", "decor_shell", "decor_lamp", "decor_castle"]
var checks := 0
var failures := 0

func _ready() -> void:
	print("G2_QA029_FIX_ACCEPTANCE_PROGRESS start")
	get_tree().create_timer(180.0).timeout.connect(_watchdog)
	_run.call_deferred()

func _watchdog() -> void:
	print("WATCHDOG_TIMEOUT")
	get_tree().quit(2)

func _run() -> void:
	GameApp.load_data_tables()
	var shop := SHOP_SCENE.instantiate()
	add_child(shop)
	await get_tree().process_frame
	var ids: Array[String] = shop._listed_item_ids()
	_check(ids == ["food_basic", "medicine_basic", "partner_egg_jellycat", "decor_seaweed", "decor_stone", "decor_shell", "decor_lamp", "decor_castle"], "data-driven shop order")
	_check(not ids.has("cookie_basic") and shop.cards.size() == 8, "cookie excluded and eight cards")
	var egg_icon: Control = shop.cards["partner_egg_jellycat"].name.get_parent().get_node("Icon")
	_check(egg_icon is TextureRect and egg_icon.texture != null and egg_icon.texture.resource_path.ends_with("egg_idle_v2_64.png"), "egg card uses approved texture")
	var med_icon: Control = shop.cards["medicine_basic"].name.get_parent().get_node("Icon")
	_check(med_icon is ColorRect and med_icon.get_child_count() == 1, "medicine remains placeholder color and initial")
	var items: Dictionary = GameApp.get_table("items")
	var original_items: Dictionary = items.duplicate(true)
	items["qa029_temp_shop_item"] = {"type":"medicine", "shop_listed":true, "shop_order":0}
	shop.refresh()
	var mutated: Array[String] = shop._listed_item_ids()
	_check(mutated.size() == 9 and mutated[0] == "qa029_temp_shop_item" and not mutated.has("cookie_basic"), "shop rebuild follows listing/order metadata")
	items.clear()
	items.merge(original_items, true)
	shop.refresh()
	_check(shop.cards.size() == 8 and not shop.cards.has("qa029_temp_shop_item"), "item table restored")
	print("G2_QA029_FIX_ACCEPTANCE_PROGRESS shop complete")
	GameState.reset_to_default()
	var owned: Array[Dictionary] = []
	for index in DECOR_IDS.size():
		owned.append({"item_id": DECOR_IDS[index], "slot": index, "purchased_at": "test"})
	GameState.data["aquarium"]["owned_decor"] = owned
	var aquarium_scene := load("res://scenes/aquarium/aquarium.tscn") as PackedScene
	var aquarium := aquarium_scene.instantiate()
	aquarium.set_process(false)
	aquarium.set_physics_process(false)
	add_child(aquarium)
	await get_tree().process_frame
	var sizes := [Vector2(1280, 720), Vector2(1280, 591), Vector2(1600, 720)]
	for screen_size in sizes:
		aquarium.call("_layout_ui", screen_size, Rect2(Vector2.ZERO, screen_size))
		aquarium.call("_refresh_decor", screen_size)
		await get_tree().process_frame
		print("QA029_DECOR_SIZE=%s water_floor_y=%.1f" % [str(screen_size), aquarium.active_water_rect.end.y])
		_check(aquarium.decor_visuals.size() == 5, "five owned decor render at %s" % str(screen_size))
		for visual in aquarium.decor_visuals:
			_check(absf(visual.position.y + visual.size.y - aquarium.active_water_rect.end.y) <= 2.0, "decor image bottom aligns with water floor at %s" % str(screen_size))
			_check(visual.position.y >= screen_size.y * 2.0 / 3.0, "decor top remains in lower third at %s" % str(screen_size))
			_check(visual.mouse_filter == Control.MOUSE_FILTER_IGNORE, "decor ignores pointer input")
			_check(not visual.get_global_rect().intersects(aquarium.pet_roster_scroll.get_global_rect()), "decor avoids nameplate row")
			_check(not visual.get_global_rect().intersects(aquarium.inventory_backdrop.get_global_rect()), "decor avoids HUD")
			_check(not visual.get_global_rect().intersects(aquarium.action_scroll.get_global_rect()), "decor avoids bottom buttons")
	print("G2_QA029_FIX_ACCEPTANCE_PROGRESS geometry complete")
	# Force each rarity band, then verify the owned-item effect is applied once.
	var diamond_chance: float = float(GameApp.get_balance_value("diamond_drop_chance", 0.0))
	var pearl_chance: float = CoinDropSystem.get_pearl_drop_chance()
	var base_value: int = FoodDropSystem.get_normal_meal_coin_value(1)
	var coin_drop: Dictionary = CoinDropSystem.roll_meal_coin(base_value, diamond_chance + pearl_chance + 0.01)
	var pearl_drop: Dictionary = CoinDropSystem.roll_meal_coin(base_value, diamond_chance + 0.001)
	var diamond_drop: Dictionary = CoinDropSystem.roll_meal_coin(base_value, 0.0)
	_check(base_value == int(GameApp.get_balance_value("meal_coin_base_value")) + 1 + int((GameApp.get_table("items")["decor_castle"]["effect"] as Dictionary).get("meal_coin_add", 0)), "normal meal value adds castle metadata exactly once")
	_check(coin_drop.get("kind") == "coin" and int(coin_drop.get("value", -1)) == base_value, "normal meal reward retains base+stage value")
	_check(pearl_drop.get("kind") == "pearl" and int(pearl_drop.get("value", -1)) == 16, "castle adds exactly one to pearl reward")
	_check(diamond_drop.get("kind") == "diamond" and int(diamond_drop.get("value", -1)) == 31, "castle adds exactly one to diamond reward")
	CoinDropSystem.use_system_rng()
	SaveManager.set_save_path_for_test("user://qa029_castle_persistence.json")
	SaveManager.reset_save()
	GameState.data["aquarium"]["owned_decor"] = owned.duplicate(true)
	_check(SaveManager.save_game(), "castle save succeeds")
	GameState.reset_to_default()
	_check(SaveManager.load_game(), "castle save reload succeeds")
	_check(GameState.get_owned_decor().any(func(entry: Dictionary) -> bool: return str(entry.get("item_id", "")) == "decor_castle"), "castle ownership persists")
	var restored_pearl: Dictionary = CoinDropSystem.roll_meal_coin(base_value, diamond_chance + 0.001)
	var restored_diamond: Dictionary = CoinDropSystem.roll_meal_coin(base_value, 0.0)
	_check(int(restored_pearl.get("value", -1)) == 16 and int(restored_diamond.get("value", -1)) == 31, "meal bonus survives reload")
	GameState.data["aquarium"]["owned_decor"] = []
	var no_castle_pearl: Dictionary = CoinDropSystem.roll_meal_coin(base_value, diamond_chance + 0.001)
	var no_castle_diamond: Dictionary = CoinDropSystem.roll_meal_coin(base_value, 0.0)
	_check(int(no_castle_pearl.get("value", -1)) == 15 and int(no_castle_diamond.get("value", -1)) == 30, "rarity values unchanged without castle")
	RuntimeLogger.clear()
	aquarium.get_parent().remove_child(aquarium)
	GameState.state_changed.emit()
	var app_errors := RuntimeLogger.get_logs().filter(func(entry: Dictionary) -> bool: return str(entry.get("level", "")) == "ERROR")
	_check(app_errors.is_empty(), "detached aquarium state callback logs no application errors")
	add_child(aquarium)
	await get_tree().process_frame
	_check(aquarium.decor_visuals.size() == GameState.get_owned_decor().size(), "decor refreshes after aquarium re-enters tree")
	if failures == 0:
		print("G2_QA029_FIX_ACCEPTANCE_OK checks=%d" % checks)
		get_tree().quit(0)
	else:
		print("G2_QA029_FIX_ACCEPTANCE_FAILED checks=%d failures=%d" % [checks, failures])
		get_tree().quit(1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("QA029: " + label)
