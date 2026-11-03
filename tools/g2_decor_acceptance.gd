extends Node

const SAVE_PATH: String = "user://g2_decor_acceptance_save.json"
var checks: int = 0
var failures: int = 0

func _ready() -> void:
	print("G2 decor: start")
	get_tree().create_timer(240.0, true, false, true).timeout.connect(_on_watchdog)
	call_deferred("_run")

func _on_watchdog() -> void:
	print("WATCHDOG_TIMEOUT")
	get_tree().quit(2)

func _run() -> void:
	GameApp.load_data_tables()
	SaveManager.set_save_path_for_test(SAVE_PATH)
	SaveManager.reset_save()
	GameState.reset_to_default()
	_check(GameApp.get_table("items").keys().filter(func(id): return str(GameApp.get_table("items")[id].get("type", "")) == "decor").size() == 5, "five decor products loaded")
	for item_id in ["decor_seaweed", "decor_stone", "decor_shell", "decor_lamp", "decor_castle"]:
		var item: Dictionary = GameApp.get_table("items")[item_id]
		_check(int(item.get("price", -1)) == 100 and bool(item.get("one_time", false)), "%s data price and one-time" % item_id)
	GameState.set_currency("bubble_coin", 99)
	_check(not ShopSystem.can_buy("decor_seaweed") and not ShopSystem.buy_item("decor_seaweed"), "insufficient funds rejected")
	_check(GameState.get_currency("bubble_coin") == 99 and GameState.get_owned_decor().is_empty(), "insufficient funds has no state mutation")
	GameState.set_currency("bubble_coin", 500)
	_check(not ShopSystem.can_buy("decor_seaweed", 2) and not ShopSystem.buy_item("decor_seaweed", 2), "decor is one-at-a-time")
	_check(not GameState.purchase_decor("decor_seaweed", 0) and GameState.get_currency("bubble_coin") == 500, "atomic transaction rejects a caller-supplied wrong price")
	_check(ShopSystem.can_buy("decor_seaweed") and ShopSystem.get_item_price("decor_seaweed") == 100, "decor price and affordability")
	_check(ShopSystem.buy_item("decor_seaweed"), "decor purchase succeeds")
	_check(GameState.get_currency("bubble_coin") == 400 and GameState.get_owned_decor().size() == 1, "purchase atomically deducts and owns")
	_check(not ShopSystem.can_buy("decor_seaweed") and not ShopSystem.buy_item("decor_seaweed"), "repurchase refused")
	_check(GameState.get_currency("bubble_coin") == 400 and GameState.get_owned_decor().size() == 1, "repurchase changes nothing")
	GameState.set_currency("bubble_coin", 500)
	for _frame in range(2):
		await get_tree().process_frame
	var before: int = GameState.get_currency("bubble_coin")
	var first: bool = ShopSystem.buy_item("decor_stone")
	var second: bool = ShopSystem.buy_item("decor_shell")
	_check(first and not second, "same-frame distinct decor purchase deduplicated")
	_check(GameState.get_currency("bubble_coin") == before - 100 and GameState.get_owned_decor().size() == 2, "same-frame only one debit")
	for _frame in range(2):
		await get_tree().process_frame
	_check(ShopSystem.buy_item("decor_shell"), "third decor purchase succeeds next frame")
	for _frame in range(2):
		await get_tree().process_frame
	_check(ShopSystem.buy_item("decor_lamp"), "lamp purchase succeeds")
	await get_tree().process_frame
	_check(ShopSystem.buy_item("decor_castle"), "castle purchase succeeds")
	await get_tree().process_frame
	_check(not ShopSystem.can_buy("decor_seaweed") and GameState.get_owned_decor().size() == 5, "five-slot limit and owned decor rejection")
	_check(is_equal_approx(CoinDropSystem.get_pearl_drop_chance(), 0.09), "lamp adds exactly 0.01 pearl chance")
	_check(is_equal_approx(CoinDropSystem.get_pearl_drop_chance(), 0.09), "lamp effect derives once from ownership")
	_check(FoodDropSystem.get_normal_meal_coin_value(1) == int(GameApp.get_balance_value("meal_coin_base_value")) + 2, "castle adds one normal meal coin")
	var pearl: Dictionary = CoinDropSystem.roll_meal_coin(10, 0.085)
	_check(str(pearl.get("kind", "")) == "pearl", "lamp pearl probability band includes 8.5 percent")
	var base_pearl: float = float(GameApp.get_balance_value("pearl_drop_chance"))
	_check(CoinDropSystem.roll_meal_coin(10, 0.115).get("kind") == "coin", "lamp bonus is exactly one percentage point")
	_check(SaveManager.save_game(), "decor save succeeds")
	GameState.reset_to_default()
	_check(SaveManager.load_game(), "decor save reload succeeds")
	_check(GameState.get_owned_decor().size() == 5 and GameState.get_currency("bubble_coin") == 100, "owned items and debit persist after reload")
	_check(is_equal_approx(CoinDropSystem.get_pearl_drop_chance(), 0.09) and FoodDropSystem.get_normal_meal_coin_value(1) == int(GameApp.get_balance_value("meal_coin_base_value")) + 2, "effects persist after reload")
	var legacy: Dictionary = GameState.to_save_dict()
	var legacy_three: Dictionary = legacy.duplicate(true)
	var pets_three: Dictionary = {}
	var active_three: Array = []
	for index in range(3):
		var id: String = "compat_three_%d" % index
		pets_three[id] = {"pet_id": id, "species_id": "normal_jellycat", "personality_id": "curious"}
		active_three.append(id)
	legacy_three["pets"] = pets_three
	var aquarium_three: Dictionary = legacy_three["aquarium"]
	aquarium_three["active_pet_ids"] = active_three
	aquarium_three.erase("owned_decor")
	legacy_three["aquarium"] = aquarium_three
	var prepared_three: Dictionary = GameState.prepare_data(legacy_three)
	_check(bool(prepared_three.get("ok", false)) and (prepared_three["data"]["pets"] as Dictionary).size() == 3 and ((prepared_three["data"]["aquarium"] as Dictionary).get("owned_decor", null) is Array), "legacy three-pet save remains compatible with empty decor default")
	var legacy_five: Dictionary = legacy_three.duplicate(true)
	var pets_five: Dictionary = legacy_five["pets"]
	var active_five: Array = (legacy_five["aquarium"] as Dictionary)["active_pet_ids"]
	for index in range(3, 5):
		var id: String = "compat_five_%d" % index
		pets_five[id] = {"pet_id": id, "species_id": "normal_jellycat", "personality_id": "curious"}
		active_five.append(id)
	legacy_five["pets"] = pets_five
	var aquarium_five: Dictionary = legacy_five["aquarium"]
	aquarium_five["active_pet_ids"] = active_five
	legacy_five["aquarium"] = aquarium_five
	var prepared_five: Dictionary = GameState.prepare_data(legacy_five)
	_check(bool(prepared_five.get("ok", false)) and (prepared_five["data"]["pets"] as Dictionary).size() == 5 and (prepared_five["data"]["aquarium"] as Dictionary).get("owned_decor", null) is Array, "five-pet save retains pets and adds decor default")
	var malformed: Dictionary = legacy_five.duplicate(true)
	var malformed_aquarium: Dictionary = malformed["aquarium"]
	malformed_aquarium["owned_decor"] = [{"item_id":"decor_lamp", "slot":4}, {"item_id":"missing", "slot":3}, {"item_id":"decor_lamp", "slot":0}, {"item_id":"decor_castle", "slot":4}, {"item_id":"decor_shell", "slot":4}, {"item_id":"decor_stone", "slot":4}, {"item_id":"decor_seaweed", "slot":4}, {"item_id":"decor_shell", "slot":2}]
	malformed["aquarium"] = malformed_aquarium
	var prepared: Dictionary = GameState.prepare_data(malformed)
	var normalized: Array = (prepared["data"]["aquarium"] as Dictionary).get("owned_decor", [])
	_check(bool(prepared.get("ok", false)) and normalized.size() == 5, "normalization removes unknowns/duplicates and caps five")
	var slots_ok: bool = true
	for index in range(normalized.size()):
		slots_ok = slots_ok and int(normalized[index].get("slot", -1)) == index
	_check(slots_ok, "normalization reindexes slots in order")
	print("G2 decor: completed checks=%d failures=%d" % [checks, failures])
	if failures == 0:
		print("G2_DECOR_ACCEPTANCE_OK checks=%d" % checks)
		get_tree().quit(0)
	else:
		print("G2_DECOR_ACCEPTANCE_FAILED checks=%d failures=%d" % [checks, failures])
		get_tree().quit(1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("G2 decor: %s %s" % ["PASS" if condition else "FAIL", label])
