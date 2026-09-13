extends Node

var failures: Array[String] = []
var checks: int = 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	GameApp.load_data_tables()
	_check_scenes()
	_check_new_game_and_hatch()
	_check_species_assets()
	_check_touch_balance()
	_check_economy()
	_check_stage_five()
	_check_save_load()
	_check_old_save_schema()
	_check_runtime_log()
	SaveManager.reset_save()
	if failures.is_empty():
		print("RUNTIME_ACCEPTANCE_OK checks=%d" % checks)
		get_tree().quit(0)
		return
	for failure in failures:
		push_error("RUNTIME_ACCEPTANCE_FAIL: %s" % failure)
	print("RUNTIME_ACCEPTANCE_FAILED checks=%d failures=%d" % [checks, failures.size()])
	get_tree().quit(1)


func _check_scenes() -> void:
	for path in [
		"res://scenes/boot/boot.tscn",
		"res://scenes/title/title.tscn",
		"res://scenes/egg_select/egg_select.tscn",
		"res://scenes/hatch/hatch.tscn",
		"res://scenes/aquarium/aquarium.tscn"
	]:
		var packed: PackedScene = ResourceLoader.load(path) as PackedScene
		_expect(packed != null, "Scene loads: %s" % path)
		if packed != null:
			var instance: Node = packed.instantiate()
			_expect(instance != null, "Scene instantiates: %s" % path)
			if instance != null:
				instance.free()


func _check_new_game_and_hatch() -> void:
	GameState.reset_to_default()
	_expect(GameState.get_currency("bubble_coin") == 20, "Initial bubble_coin is 20")
	_expect(GameState.get_inventory_count("food_basic") == 5, "Initial food is 5")
	_expect(GameState.get_inventory_count("cookie_basic") == 3, "Initial cookie is 3")
	_expect(GameState.get_inventory_count("medicine_basic") == 1, "Initial medicine is 1")
	EggSystem.select_starter_egg()
	for _tap in range(10):
		HatchSystem.tap_egg()
	var egg: Variant = GameState.get_egg()
	_expect(egg is Dictionary and bool(egg.get("is_hatched", false)), "Egg hatches after 10 taps")
	_expect(GameState.has_jellycat(), "Hatch creates JellyCat")


func _check_species_assets() -> void:
	var packed: PackedScene = ResourceLoader.load("res://scenes/pet/jellycat_actor.tscn") as PackedScene
	_expect(packed != null, "JellyCat actor scene loads")
	if packed == null:
		return
	var actor: Node = packed.instantiate()
	add_child(actor)
	actor.call("set_stage", 5)
	var sprite: Sprite2D = actor.get_node("%Sprite") as Sprite2D
	_expect(sprite != null and sprite.texture != null, "Normal JellyCat Stage 5 texture loads")
	if sprite != null and sprite.texture != null:
		_expect(sprite.texture.resource_path.ends_with("assets/jellycats/normal_jellycat/stages/stage_5.png"), "Stage texture follows species asset convention")
	var jellycat: Dictionary = (GameState.get_jellycat() as Dictionary).duplicate(true)
	jellycat["species_id"] = "future_jellycat"
	GameState.set_jellycat(jellycat)
	actor.call("set_stage", 3)
	_expect(sprite != null and sprite.texture != null, "Missing species texture uses fallback")
	if sprite != null and sprite.texture != null:
		_expect(sprite.texture.resource_path.ends_with("assets/jellycats/normal_jellycat/stages/stage_3.png"), "Fallback uses normal JellyCat at the same stage")
	jellycat["species_id"] = "normal_jellycat"
	GameState.set_jellycat(jellycat)
	actor.free()


func _check_touch_balance() -> void:
	var jellycat: Dictionary = (GameState.get_jellycat() as Dictionary).duplicate(true)
	jellycat["mood"] = 0
	jellycat["growth_exp"] = 0
	GameState.set_jellycat(jellycat)
	var window_started_at: float = Time.get_unix_time_from_system()
	GameState.set_care_stats({
		"touch_growth_exp_today": 0,
		"touch_exp_date": str(window_started_at),
		"last_touch_effect_at": 0.0,
		"touch_cap_notified_date": ""
	})
	_expect(CareSystem.touch_pet(), "First Touch succeeds")
	var exp_after_first: int = int((GameState.get_jellycat() as Dictionary).get("growth_exp", -1))
	_expect(not CareSystem.touch_pet(), "Immediate Touch is blocked by cooldown")
	_expect(int((GameState.get_jellycat() as Dictionary).get("growth_exp", -1)) == exp_after_first, "Cooldown Touch adds no EXP")
	for _touch in range(19):
		var stats: Dictionary = GameState.get_care_stats()
		stats["last_touch_effect_at"] = 0.0
		GameState.set_care_stats(stats)
		CareSystem.touch_pet()
	var after_cap: Dictionary = GameState.get_jellycat() as Dictionary
	_expect(int(after_cap.get("growth_exp", -1)) == 20, "Touch grants exactly 20 EXP per window")
	_expect(int(GameState.get_care_stats().get("touch_growth_exp_today", -1)) == 20, "Touch counter reaches 20/20")
	var capped_exp: int = int(after_cap.get("growth_exp", -1))
	var capped_stats: Dictionary = GameState.get_care_stats()
	capped_stats["last_touch_effect_at"] = 0.0
	GameState.set_care_stats(capped_stats)
	_expect(not CareSystem.touch_pet(), "Touch after 20/20 is a no-op")
	_expect(int((GameState.get_jellycat() as Dictionary).get("growth_exp", -1)) == capped_exp, "Touch after cap adds no EXP")
	var expired_stats: Dictionary = GameState.get_care_stats()
	expired_stats["touch_exp_date"] = str(Time.get_unix_time_from_system() - 601.0)
	expired_stats["last_touch_effect_at"] = 0.0
	GameState.set_care_stats(expired_stats)
	_expect(CareSystem.touch_pet(), "Touch succeeds after the 10-minute window expires")
	_expect(int(GameState.get_care_stats().get("touch_growth_exp_today", -1)) == 1, "Expired Touch window resets counter to 1")
	var legacy_stats: Dictionary = GameState.get_care_stats()
	legacy_stats["touch_growth_exp_today"] = 20
	legacy_stats["touch_exp_date"] = "2026-08-01"
	legacy_stats["last_touch_effect_at"] = 0.0
	GameState.set_care_stats(legacy_stats)
	_expect(CareSystem.touch_pet(), "Legacy daily Touch save starts a new 10-minute window")
	_expect(int(GameState.get_care_stats().get("touch_growth_exp_today", -1)) == 1, "Legacy daily counter migrates safely")
	var food_exp: int = int((GameState.get_jellycat() as Dictionary).get("growth_exp", 0))
	_expect(CareSystem.feed_food(), "Food still works after Touch cap")
	_expect(int((GameState.get_jellycat() as Dictionary).get("growth_exp", 0)) > food_exp, "Food still adds EXP")
	var cookie_exp: int = int((GameState.get_jellycat() as Dictionary).get("growth_exp", 0))
	_expect(CareSystem.feed_cookie(), "Cookie still works after Touch cap")
	_expect(int((GameState.get_jellycat() as Dictionary).get("growth_exp", 0)) > cookie_exp, "Cookie still adds EXP")


func _check_economy() -> void:
	GameState.set_currency("bubble_coin", 100)
	var old_food: int = GameState.get_inventory_count("food_basic")
	_expect(ShopSystem.buy_item("food_basic"), "Shop buys food")
	_expect(GameState.get_currency("bubble_coin") == 95, "Food purchase costs 5 coins")
	_expect(GameState.get_inventory_count("food_basic") == old_food + 1, "Food purchase adds inventory")
	_expect(ShopSystem.buy_item("cookie_basic"), "Shop buys cookie")
	_expect(GameState.get_currency("bubble_coin") == 87, "Cookie purchase costs 8 coins")
	_expect(ShopSystem.buy_item("medicine_basic"), "Shop buys medicine")
	_expect(GameState.get_currency("bubble_coin") == 67, "Medicine purchase costs 20 coins")
	GameState.set_currency("bubble_coin", 0)
	var medicine_before: int = GameState.get_inventory_count("medicine_basic")
	_expect(not ShopSystem.buy_item("medicine_basic"), "Insufficient coin purchase fails")
	_expect(GameState.get_currency("bubble_coin") == 0, "Currency never falls below zero")
	_expect(GameState.get_inventory_count("medicine_basic") == medicine_before, "Failed purchase changes no inventory")
	var jellycat: Dictionary = (GameState.get_jellycat() as Dictionary).duplicate(true)
	jellycat["mood"] = 100
	GameState.set_jellycat(jellycat)
	_expect(CurrencySystem.calculate_offline_income(60) == 2, "Offline income calculates once per interval")


func _check_stage_five() -> void:
	var jellycat: Dictionary = (GameState.get_jellycat() as Dictionary).duplicate(true)
	jellycat["stage"] = 1
	jellycat["growth_exp"] = 900
	GameState.set_jellycat(jellycat)
	GameState.set_currency("bubble_coin", 0)
	for expected_stage in range(2, 6):
		_expect(EvolutionSystem.evolve(), "Evolution reaches Stage %d" % expected_stage)
		_expect(int((GameState.get_jellycat() as Dictionary).get("stage", 0)) == expected_stage, "Stage is %d" % expected_stage)
	var coin_at_stage_five: int = GameState.get_currency("bubble_coin")
	_expect(EvolutionSystem.get_next_stage_data().is_empty(), "Stage 5 has no next-stage data")
	_expect(not EvolutionSystem.evolve(), "Stage 5 evolve is safely rejected")
	_expect(int((GameState.get_jellycat() as Dictionary).get("stage", 0)) == 5, "Stage never exceeds 5")
	_expect(GameState.get_currency("bubble_coin") == coin_at_stage_five, "Stage 5 gives no duplicate bonus")


func _check_save_load() -> void:
	var expected: Dictionary = GameState.to_save_dict()
	_expect(SaveManager.save_game(), "Save succeeds")
	GameState.reset_to_default()
	_expect(SaveManager.load_game(), "Load succeeds")
	var loaded: Dictionary = GameState.to_save_dict()
	var expected_jellycat: Dictionary = expected.get("jellycat", {}) as Dictionary
	var loaded_jellycat: Dictionary = loaded.get("jellycat", {}) as Dictionary
	for key in ["stage", "growth_exp", "hunger", "mood", "cleanliness"]:
		_expect(int(loaded_jellycat.get(key, -1)) == int(expected_jellycat.get(key, -2)), "Save/Load preserves jellycat.%s" % key)
	_expect(str(loaded_jellycat.get("health", "")) == str(expected_jellycat.get("health", "missing")), "Save/Load preserves jellycat.health")
	_expect(GameState.get_currency("bubble_coin") == int((expected.get("currency", {}) as Dictionary).get("bubble_coin", -1)), "Save/Load preserves bubble_coin")
	var expected_inventory: Dictionary = expected.get("inventory", {}) as Dictionary
	for key in ["food_basic", "cookie_basic", "medicine_basic"]:
		_expect(GameState.get_inventory_count(key) == int(expected_inventory.get(key, -1)), "Save/Load preserves inventory.%s" % key)
	var expected_stats: Dictionary = expected.get("care_stats", {}) as Dictionary
	var loaded_stats: Dictionary = GameState.get_care_stats()
	_expect(int(loaded_stats.get("touch_growth_exp_today", -1)) == int(expected_stats.get("touch_growth_exp_today", -2)), "Save/Load preserves touch_growth_exp_today")
	_expect(str(loaded_stats.get("touch_exp_date", "")) == str(expected_stats.get("touch_exp_date", "missing")), "Save/Load preserves touch_exp_date")
	_expect(float(loaded_stats.get("last_touch_effect_at", -1.0)) == float(expected_stats.get("last_touch_effect_at", -2.0)), "Save/Load preserves last_touch_effect_at")
	_expect(str(loaded_stats.get("touch_cap_notified_date", "")) == str(expected_stats.get("touch_cap_notified_date", "missing")), "Save/Load preserves touch_cap_notified_date")


func _check_old_save_schema() -> void:
	GameState.set_data({
		"jellycat": {"species_id": "normal_jellycat"}
	})
	_expect(GameState.get_currency("bubble_coin") == 20, "Old save receives currency default")
	_expect(GameState.get_inventory_count("food_basic") == 5, "Old save receives food default")
	var stats: Dictionary = GameState.get_care_stats()
	for key in ["touch_growth_exp_today", "touch_exp_date", "last_touch_effect_at", "touch_cap_notified_date"]:
		_expect(stats.has(key), "Old save receives care_stats.%s" % key)
	for key in ["last_saved_at", "last_opened_at", "last_passive_coin_at"]:
		_expect(GameState.to_save_dict().get("timestamps", {}).has(key), "Old save receives timestamps.%s" % key)
	var jellycat: Dictionary = GameState.get_jellycat() as Dictionary
	_expect(int(jellycat.get("stage", 0)) == 1, "Old JellyCat receives Stage 1")
	_expect(str(jellycat.get("health", "")) == "healthy", "Old JellyCat receives healthy state")


func _check_runtime_log() -> void:
	RuntimeLogger.clear()
	for index in range(105):
		RuntimeLogger.log_info("acceptance log %d" % index)
	_expect(RuntimeLogger.get_logs().size() == 100, "Runtime Log keeps latest 100 entries")
	RuntimeLogger.clear()
	_expect(RuntimeLogger.get_logs().is_empty(), "Runtime Log clear works")


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

