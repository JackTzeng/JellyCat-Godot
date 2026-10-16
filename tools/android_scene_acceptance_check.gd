extends Node

const ISOLATED_SAVE_PATH: String = "user://android_build_gate_save.json"
const BOOT_SCENE: String = "res://scenes/boot/boot.tscn"
const TITLE_SCENE: String = "res://scenes/title/title.tscn"
const EGG_SELECT_SCENE: String = "res://scenes/egg_select/egg_select.tscn"
const HATCH_SCENE: String = "res://scenes/hatch/hatch.tscn"
const AQUARIUM_SCENE: String = "res://scenes/aquarium/aquarium.tscn"

var failures: Array[String] = []
var isolated_save_ready: bool = false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await get_tree().process_frame
	var save_manager: Variant = get_tree().root.get_node_or_null("SaveManager")
	if save_manager == null or not save_manager.set_save_path_for_test(ISOLATED_SAVE_PATH):
		_fail("Could not select the isolated user:// save path")
		_finish()
		return
	isolated_save_ready = true
	save_manager.reset_save()
	var game_app: Variant = get_tree().root.get_node("GameApp")
	game_app.load_data_tables()

	var boot: Node = _load_scene(BOOT_SCENE)
	if boot == null:
		_finish()
		return
	get_tree().root.add_child(boot)
	get_tree().current_scene = boot
	var reached_scene: bool = await _wait_for_scene(TITLE_SCENE)
	if not reached_scene or not bool(game_app.loaded):
		_fail("Production Boot did not finish GameApp boot and load Title")
		_finish()
		return
	var title: Node = get_tree().current_scene
	var new_game_button: Button = title.get_node_or_null("%NewGameButton") as Button
	if new_game_button == null:
		_fail("Title scene did not create its New Game button")
		_finish()
		return
	new_game_button.pressed.emit()
	reached_scene = await _wait_for_scene(EGG_SELECT_SCENE)
	if not reached_scene:
		_fail("New Game did not load the egg selection scene")
		_finish()
		return
	if not _saved_payload_is_valid():
		_fail("New Game did not persist its save inside the isolated path")
		_finish()
		return

	var egg_select: Node = get_tree().current_scene
	var select_button: Button = egg_select.get_node_or_null("%SelectButton") as Button
	if select_button == null:
		_fail("Egg Select scene did not create its Select button")
		_finish()
		return
	select_button.pressed.emit()
	reached_scene = await _wait_for_scene(HATCH_SCENE)
	if not reached_scene:
		_fail("Selecting the starter egg did not load the hatch scene")
		_finish()
		return

	var hatch: Node = get_tree().current_scene
	var egg_button: Button = hatch.get_node_or_null("%EggButton") as Button
	if egg_button == null:
		_fail("Hatch scene did not create its egg button")
		_finish()
		return
	for _tap in range(10):
		egg_button.pressed.emit()
		await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	reached_scene = await _wait_for_scene(AQUARIUM_SCENE)
	if not reached_scene:
		_fail("Hatching did not load the aquarium scene")
		_finish()
		return

	var aquarium: Node = get_tree().current_scene
	var feed_button: Button = aquarium.get_node_or_null("%FeedButton") as Button
	if feed_button == null:
		_fail("Aquarium scene did not create its Feed button")
		_finish()
		return
	var game_state: Variant = get_tree().root.get_node("GameState")
	var before_food: int = int(game_state.get_inventory_count("food_basic"))
	feed_button.pressed.emit()
	var food_reserved: bool = false
	var feed_deadline_msec: int = Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < feed_deadline_msec:
		await get_tree().process_frame
		if game_state.get_food_drops().size() == 1:
			food_reserved = true
			break
	_expect(food_reserved, "Aquarium Feed reserves one unlimited-food token within five seconds")
	_expect(int(game_state.get_inventory_count("food_basic")) == before_food, "Aquarium Feed leaves the legacy food_basic quantity unchanged")
	var daily_claim_before: Dictionary = game_state.get_daily_claim()
	daily_claim_before["last_free_food_date"] = "legacy-marker"
	game_state.set_daily_claim(daily_claim_before)
	var daily_snapshot: Dictionary = game_state.get_daily_claim().duplicate(true)
	var coins_before_daily: int = int(game_state.get_currency("bubble_coin"))
	(aquarium.get_node("%DailyFoodButton") as Button).pressed.emit()
	_expect(game_state.get_daily_claim() == daily_snapshot, "Daily unlimited-food prompt leaves the legacy claim date unchanged")
	_expect(int(game_state.get_inventory_count("food_basic")) == before_food and int(game_state.get_currency("bubble_coin")) == coins_before_daily, "Daily unlimited-food prompt changes neither inventory nor currency")
	_expect(str((aquarium.get_node("%MessageLabel") as Label).text) == "飼料已無限", "Daily unlimited-food prompt shows the approved message")
	(aquarium.get_node("%ShopButton") as Button).pressed.emit()
	var shop_panel: Control = aquarium.get_node("%ShopPanel") as Control
	var shop_food_label: Label = shop_panel.get_node("%FoodInfoLabel") as Label
	var shop_food_button: Button = shop_panel.get_node("%BuyFoodButton") as Button
	_expect(shop_panel.visible and shop_food_label.text.contains("∞") and shop_food_label.text.contains("飼料無限") and shop_food_button.disabled, "Android Aquarium shop displays unlimited food with buying disabled")
	_expect(not ShopSystem.buy_item("food_basic"), "Android shop transaction rejects food purchases")
	_expect(int(game_state.get_inventory_count("food_basic")) == before_food and int(game_state.get_currency("bubble_coin")) == coins_before_daily, "Rejected Android shop purchase preserves inventory and currency")
	(shop_panel.get_node("%CloseShopButton") as Button).pressed.emit()
	_expect(not shop_panel.visible, "Shop closes after the unlimited-food purchase check")
	_expect(bool(save_manager.save_game()), "Aquarium operation saves through the isolated path")
	_expect(_saved_payload_is_valid(), "Saved JSON can be reopened from the isolated path")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_manager.get_save_path()))
	if saved is Dictionary:
		var saved_inventory: Dictionary = saved.get("inventory", {}) as Dictionary
		_expect(int(saved_inventory.get("food_basic", -1)) == before_food, "Saved JSON preserves the legacy food_basic field unchanged")
	_finish()


func _load_scene(path: String) -> Node:
	var packed: PackedScene = ResourceLoader.load(path) as PackedScene
	if packed == null:
		_fail("Could not load scene: %s" % path)
		return null
	var instance: Node = packed.instantiate()
	if instance == null:
		_fail("Could not instantiate scene: %s" % path)
	return instance


func _wait_for_scene(path: String) -> bool:
	var router: Variant = get_tree().root.get_node("SceneRouter")
	for _frame in range(120):
		await get_tree().process_frame
		if str(router.current_scene_path) == path and get_tree().current_scene != null:
			return true
	return false


func _saved_payload_is_valid() -> bool:
	var save_manager: Variant = get_tree().root.get_node("SaveManager")
	if not save_manager.has_save():
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_manager.get_save_path()))
	return parsed is Dictionary and int((parsed as Dictionary).get("schema_version", 0)) == 2


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_fail(label)


func _fail(message: String) -> void:
	failures.append(message)
	push_error("ANDROID_SCENE_ACCEPTANCE_FAIL: %s" % message)


func _finish() -> void:
	var exit_code: int = 1 if not failures.is_empty() else 0
	var save_manager: Variant = get_tree().root.get_node_or_null("SaveManager")
	if isolated_save_ready and save_manager != null:
		save_manager.reset_save()
		if save_manager.has_save():
			push_error("ANDROID_SCENE_ACCEPTANCE_FAIL: isolated save cleanup failed")
			exit_code = 1
		save_manager.use_production_save_path()
	if exit_code == 0:
		print("ANDROID_SCENE_ACCEPTANCE_OK scenes=5 ui_actions=16 production_boot=true isolated_save=true")
	else:
		for failure in failures:
			push_error("ANDROID_SCENE_ACCEPTANCE_FAILURE: %s" % failure)
		print("ANDROID_SCENE_ACCEPTANCE_FAILED failures=%d" % failures.size())
	get_tree().quit(exit_code)
