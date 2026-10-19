extends Node

const ISOLATED_SAVE_PATH: String = "user://jellycat_g1_acceptance_save.json"

var failures: Array[String] = []
var checks: int = 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var isolated_path_set: bool = SaveManager.set_save_path_for_test(ISOLATED_SAVE_PATH)
	_expect(isolated_path_set, "Acceptance uses an isolated user:// save path")
	if not isolated_path_set:
		_finish()
		return
	SaveManager.reset_save()
	GameApp.load_data_tables()
	_check_scenes()
	_check_three_pet_hatch_and_care()
	_check_touch_balance()
	_check_evolution_and_economy()
	_check_json_round_trip_and_save_load()
	_check_legacy_migration_and_backup_recovery()
	_check_invalid_save_preservation()
	_check_g2_care_regressions()
	_check_day1_simulation()
	_check_one_hour_progression()
	_check_runtime_log()
	SaveManager.reset_save()
	_expect(not SaveManager.has_save(), "Acceptance cleanup removes only its isolated save")
	SaveManager.use_production_save_path()
	_finish()


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


func _check_three_pet_hatch_and_care() -> void:
	GameState.reset_to_default()
	_expect(int((GameState.get_aquarium()).get("capacity", 0)) == 3, "G1 new aquarium capacity starts at three")
	_expect(GameState.get_currency("bubble_coin") == 20, "New game starts with 20 bubble coins")
	_expect(GameState.get_inventory_count("food_basic") == 5, "New game retains the legacy food_basic field default")
	_expect(GameState.get_inventory_count("cookie_basic") == 3, "New game starts with three cookies")
	_expect(GameState.get_inventory_count("medicine_basic") == 1, "New game starts with one medicine")
	var eggs: Array[Dictionary] = EggSystem.ensure_starter_eggs()
	_expect(eggs.size() == 3, "New game receives three starter eggs")
	var starter_personalities: Array[String] = ["curious", "affectionate", "sleepy"]
	var queued_pet_ids: Array[String] = []
	var egg_ids: Array[String] = []
	for index in range(eggs.size()):
		var egg: Dictionary = eggs[index]
		queued_pet_ids.append(str(egg.get("pet_id", "")))
		egg_ids.append(str(egg.get("egg_id", "")))
		_expect(str(egg.get("personality_id", "")) == starter_personalities[index], "Starter egg %d stores its personality" % (index + 1))
	_expect(queued_pet_ids.size() == 3 and queued_pet_ids[0] != queued_pet_ids[1] and queued_pet_ids[1] != queued_pet_ids[2], "Starter eggs reserve unique pet IDs")
	_expect(egg_ids.size() == 3 and egg_ids[0] != egg_ids[1] and egg_ids[1] != egg_ids[2], "Starter eggs have unique nursery IDs")
	_expect(EggSystem.select_starter_egg(egg_ids[0]), "First starter egg can be selected by ID")
	var first_hatch: Dictionary = {}
	for _tap in range(10):
		first_hatch = HatchSystem.tap_egg(egg_ids[0])
	_expect(bool(first_hatch.get("is_hatched", false)), "First egg hatches after ten taps")
	_expect(GameState.get_pet_ids().size() == 1, "First hatch creates one saved pet")
	for egg_index in range(1, egg_ids.size()):
		var egg_id: String = egg_ids[egg_index]
		_expect(EggSystem.select_starter_egg(egg_id), "Companion egg %d can be selected" % (egg_index + 1))
		var hatched: Dictionary = {}
		for _tap in range(10):
			hatched = HatchSystem.tap_egg(egg_id)
		_expect(bool(hatched.get("is_hatched", false)), "Companion egg %d hatches" % (egg_index + 1))
	var pet_ids: Array[String] = GameState.get_pet_ids()
	_expect(pet_ids.size() == 3, "All three JellyCats have hatched")
	_expect(GameState.get_active_pet_ids().size() == 3, "All three JellyCats share the aquarium")
	var seen_personalities: Dictionary = {}
	for pet_id in pet_ids:
		var pet: Dictionary = GameState.get_pet(pet_id)
		seen_personalities[str(pet.get("personality_id", ""))] = true
		_expect(int(pet.get("vitality", 0)) == 100, "%s starts with reserved vitality 100" % pet_id)
		_expect(not str(pet.get("nickname", "")).is_empty(), "%s receives a nickname" % pet_id)
		_expect(pet.get("care_stats", {}) is Dictionary, "%s has per-pet care stats" % pet_id)
		_expect(pet.get("visual_params", {}) is Dictionary, "%s has visual parameters" % pet_id)
	_expect(seen_personalities.size() == 3, "The three starter pets have three distinct personalities")
	var count_before_fake_hatch: int = pet_ids.size()
	_expect(HatchSystem.create_pet_from_egg("egg_missing").is_empty(), "Removed or fake egg ID cannot create a pet")
	_expect(GameState.get_pet_ids().size() == count_before_fake_hatch, "Rejected hatch leaves no ghost pet")
	var pet_a_id: String = pet_ids[0]
	var pet_b_id: String = pet_ids[1]
	var pet_a: Dictionary = GameState.get_pet(pet_a_id)
	pet_a["hunger"] = 70
	GameState.set_pet(pet_a_id, pet_a)
	pet_a = GameState.get_pet(pet_a_id)
	var pet_b: Dictionary = GameState.get_pet(pet_b_id)
	var pet_b_before: Dictionary = pet_b.duplicate(true)
	var food_before: int = GameState.get_inventory_count("food_basic")
	_expect(CareSystem.feed_food(pet_a_id), "Food feeds the explicitly selected pet")
	_expect(GameState.get_inventory_count("food_basic") == food_before, "Unlimited food leaves the legacy food_basic quantity unchanged")
	_expect(int(GameState.get_pet(pet_a_id).get("hunger", 0)) > int(pet_a.get("hunger", 0)), "Food raises the target pet's hunger stat")
	_expect(int(GameState.get_pet(pet_b_id).get("hunger", 0)) == int(pet_b_before.get("hunger", -1)), "Food does not change another pet's stats")
	var cookie_before: int = GameState.get_inventory_count("cookie_basic")
	_expect(CareSystem.feed_cookie(pet_b_id), "Cookie still feeds the explicitly selected pet")
	_expect(GameState.get_inventory_count("cookie_basic") == cookie_before - 1, "Cookie feed still deducts one inventory item")
	InventorySystem.add_item("cookie_basic", 1)
	_expect(GameState.get_inventory_count("cookie_basic") == cookie_before, "Cookie refund through InventorySystem restores the exact prior count")
	GameState.set_inventory_count("food_basic", 0)
	pet_b = GameState.get_pet(pet_b_id)
	pet_b["hunger"] = 70
	GameState.set_pet(pet_b_id, pet_b)
	_expect(CareSystem.feed_food(pet_b_id), "Unlimited food remains usable when the legacy count is zero")
	_expect(GameState.get_inventory_count("food_basic") == 0, "Feeding with a zero legacy count does not change it")
	GameState.set_inventory_count("food_basic", food_before)
	var invalid_pet: Dictionary = pet_a.duplicate(true)
	_expect(not GameState.set_pet(" %s " % pet_a_id, invalid_pet), "Pet mutators reject padded IDs")
	_expect(not GameState.add_pet({"pet_id": " jc_004 ", "personality_id": "curious"}), "Pet creation rejects padded IDs")
	_expect(not GameState.set_selected_pet_id("missing_pet"), "Selection rejects unknown pet IDs")
	_expect(not GameState.rename_pet("missing_pet", "Ghost"), "Rename rejects unknown pet IDs")
	var inventory_before_invalid_feed: int = GameState.get_inventory_count("food_basic")
	_expect(not CareSystem.feed_food("missing_pet"), "Care system rejects unknown pet IDs")
	_expect(GameState.get_inventory_count("food_basic") == inventory_before_invalid_feed, "Rejected feed does not spend shared inventory")
	var colliding_keys: Dictionary = {
		pet_a_id: pet_a,
		" %s " % pet_a_id: pet_a.duplicate(true)
	}
	var collision_result: Dictionary = GameState.prepare_data({"schema_version": 2, "pets": colliding_keys})
	_expect(not bool(collision_result.get("ok", false)), "Save migration rejects whitespace-colliding pet keys")


func _check_touch_balance() -> void:
	var pet_id: String = GameState.get_pet_ids()[0]
	var pet: Dictionary = GameState.get_pet(pet_id)
	pet["mood"] = 0
	pet["growth_exp"] = 0
	var touch_exp_add: int = int(GameApp.get_balance_value("touch_growth_exp_add"))
	var touch_cap: int = int(GameApp.get_balance_value("touch_growth_exp_cap"))
	var touch_mood_add: int = int(GameApp.get_balance_value("touch_mood_add"))
	var max_mood: int = int(GameApp.get_balance_value("max_mood"))
	var touch_cooldown: float = float(GameApp.get_balance_value("touch_cooldown_seconds"))
	var reset_seconds: float = float(GameApp.get_balance_value("touch_exp_reset_seconds"))
	var initial_stats: Dictionary = {
		"touch_growth_exp_hour": 0,
		"touch_exp_hour_started_at": 0.0,
		"touch_exp_hour_id": "",
		"last_touch_effect_at": 0.0,
		"touch_cap_notified_hour_id": ""
	}
	GameState.set_pet_and_care_stats(pet_id, pet, initial_stats)
	RuntimeLogger.clear()
	var injected_now: float = Time.get_unix_time_from_system()
	_expect(CareSystem.touch_pet(pet_id, injected_now), "First touch succeeds for explicit pet ID")
	var exp_after_first: int = int(GameState.get_pet(pet_id).get("growth_exp", -1))
	_expect(not CareSystem.touch_pet(pet_id, injected_now + touch_cooldown / 2.0), "Immediate touch is blocked by configured cooldown")
	_expect(int(GameState.get_pet(pet_id).get("growth_exp", -1)) == exp_after_first, "Cooldown touch adds no EXP")
	_expect(RuntimeLogger.get_log_text().contains("Touch ignored for %s: cooldown" % pet_id), "Touch cooldown log carries the stable pet ID on the same line")
	var touch_calls_needed: int = int(ceil(float(touch_cap) / float(max(touch_exp_add, 1))))
	var touch_spacing: float = maxf(touch_cooldown * 2.0, 0.01)
	for touch_index in range(1, touch_calls_needed):
		CareSystem.touch_pet(pet_id, injected_now + float(touch_index) * touch_spacing)
	var after_cap: Dictionary = GameState.get_current_care_stats(pet_id)
	_expect(int(after_cap.get("touch_growth_exp_hour", -1)) == touch_cap, "Touch grants exactly the configured hourly EXP cap")
	var capped_pet: Dictionary = GameState.get_pet(pet_id)
	var capped_exp: int = int(capped_pet.get("growth_exp", -1))
	capped_pet["mood"] = maxi(0, max_mood - touch_mood_add)
	GameState.set_pet(pet_id, capped_pet)
	var mood_before_capped_touch: int = int(GameState.get_pet(pet_id).get("mood", -1))
	var after_cap_touch_at: float = injected_now + float(touch_calls_needed) * touch_spacing
	_expect(CareSystem.touch_pet(pet_id, after_cap_touch_at), "Touch remains available after the hourly EXP cap")
	_expect(int(GameState.get_pet(pet_id).get("growth_exp", -1)) == capped_exp and int(GameState.get_pet(pet_id).get("mood", -1)) == mini(max_mood, mood_before_capped_touch + touch_mood_add), "Touch after cap adds configured mood but no EXP")
	_expect(CareSystem.touch_pet(pet_id, injected_now + reset_seconds), "Touch succeeds after the configured rolling hour")
	_expect(int(GameState.get_current_care_stats(pet_id).get("touch_growth_exp_hour", -1)) == mini(touch_exp_add, touch_cap), "Touch hourly counter resets after the configured duration")
	var touch_log_lines_have_pet_id: bool = true
	var touch_log_line_count: int = 0
	for log_entry in RuntimeLogger.get_logs():
		if not (log_entry is Dictionary):
			continue
		var log_message: String = str((log_entry as Dictionary).get("message", ""))
		if log_message.contains("touch") or log_message.contains("Touch") or log_message.contains("mood:") or log_message.contains("growth_exp:"):
			touch_log_line_count += 1
			touch_log_lines_have_pet_id = touch_log_lines_have_pet_id and log_message.contains(pet_id)
	_expect(touch_log_line_count > 0 and touch_log_lines_have_pet_id, "Every emitted touch, cooldown, mood, and touch-growth log line carries the stable pet ID")
	var other_id: String = GameState.get_pet_ids()[1]
	_expect(int(GameState.get_current_care_stats(other_id).get("touch_growth_exp_hour", -1)) == 0, "Touch cap is saved independently for each pet")
	var before_food_exp: int = int(GameState.get_pet(pet_id).get("growth_exp", 0))
	pet = GameState.get_pet(pet_id)
	var food: Dictionary = GameApp.get_table("items").get("food_basic", {}) as Dictionary
	pet["hunger"] = int(GameApp.get_balance_value("food_refusal_hunger_threshold"))
	GameState.set_pet(pet_id, pet)
	_expect(CareSystem.feed_food(pet_id), "Food still works after the touch cap")
	_expect(int(GameState.get_pet(pet_id).get("growth_exp", 0)) == before_food_exp + int(food.get("growth_exp_add", 0)), "Food grants its configured growth EXP after the touch cap")
	var before_cookie_exp: int = int(GameState.get_pet(pet_id).get("growth_exp", 0))
	_expect(CareSystem.feed_cookie(pet_id), "Cookie still works after the touch cap")
	var cookie: Dictionary = GameApp.get_table("items").get("cookie_basic", {}) as Dictionary
	_expect(int(GameState.get_pet(pet_id).get("growth_exp", 0)) == before_cookie_exp + int(cookie.get("growth_exp_add", 0)), "Cookie grants its configured growth EXP after the touch cap")
	var final_stats: Dictionary = GameState.get_current_care_stats(pet_id)
	final_stats["last_touch_effect_at"] = 0.0
	final_stats["touch_exp_hour_started_at"] = 0.0
	final_stats["touch_growth_exp_hour"] = 0
	GameState.set_pet_and_care_stats(pet_id, GameState.get_pet(pet_id), final_stats)


func _check_evolution_and_economy() -> void:
	var pet_id: String = GameState.get_pet_ids()[0]
	var pet: Dictionary = GameState.get_pet(pet_id)
	var species_id: String = str(pet.get("species_id", "normal_jellycat"))
	var evolution: Dictionary = GameApp.get_table("evolution").get(species_id, {}) as Dictionary
	var stages: Array = evolution.get("stages", []) as Array
	var first_stage: Dictionary = stages[0] as Dictionary if not stages.is_empty() else {}
	var final_stage: Dictionary = stages[stages.size() - 1] as Dictionary if not stages.is_empty() else {}
	var max_stage: int = int(final_stage.get("stage", 0))
	var max_growth_exp: int = int(final_stage.get("required_growth_exp", 0))
	pet["stage"] = int(first_stage.get("stage", 1))
	pet["growth_exp"] = 0
	GameState.set_pet(pet_id, pet)
	GameState.set_currency("bubble_coin", 0)
	RuntimeLogger.clear()
	_expect(not EvolutionSystem.evolve(pet_id), "Evolution below the required EXP is safely rejected")
	var insufficient_evolution_log: String = RuntimeLogger.get_log_text()
	_expect(insufficient_evolution_log.contains(" INFO Cannot evolve yet") and not insufficient_evolution_log.contains(" ERROR Cannot evolve yet"), "Insufficient EXP is logged at INFO, not ERROR severity")
	pet["growth_exp"] = max_growth_exp
	GameState.set_pet(pet_id, pet)
	for stage_index in range(1, stages.size()):
		var expected_stage: int = int((stages[stage_index] as Dictionary).get("stage", 0))
		_expect(EvolutionSystem.can_evolve(pet_id), "%s can evolve to Stage %d" % [pet_id, expected_stage])
		_expect(EvolutionSystem.evolve(pet_id), "Evolution reaches Stage %d" % expected_stage)
		_expect(int(GameState.get_pet(pet_id).get("stage", 0)) == expected_stage, "Stage is %d" % expected_stage)
		var durable_save: Variant = JSON.parse_string(_read_text(SaveManager.get_save_path()))
		var durable_pets: Dictionary = (durable_save as Dictionary).get("pets", {}) if durable_save is Dictionary else {}
		var durable_pet: Dictionary = durable_pets.get(pet_id, {})
		_expect(int(durable_pet.get("stage", 0)) == expected_stage, "Evolution persists stage %d immediately" % expected_stage)
		var durable_currency: Dictionary = (durable_save as Dictionary).get("currency", {}) if durable_save is Dictionary else {}
		_expect(int(durable_currency.get("bubble_coin", -1)) == GameState.get_currency("bubble_coin"), "Evolution persists its shared coin bonus immediately")
	_expect(EvolutionSystem.get_next_stage_data(pet_id).is_empty(), "Maximum stage has no next-stage data")
	_expect(not EvolutionSystem.evolve(pet_id), "Maximum-stage evolution is safely rejected")
	_expect(not EvolutionSystem.evolve("missing_pet"), "Evolution rejects unknown pet IDs")
	_expect(int(GameState.get_pet(pet_id).get("stage", 0)) == max_stage, "Stage never exceeds configured maximum")
	GameState.set_currency("bubble_coin", 100)
	var old_food: int = GameState.get_inventory_count("food_basic")
	_expect(not ShopSystem.can_buy("food_basic"), "Unlimited food is not a purchasable shop item")
	_expect(not ShopSystem.buy_item("food_basic"), "Food purchase transaction is rejected")
	_expect(GameState.get_currency("bubble_coin") == 100, "Rejected food purchase leaves currency unchanged")
	_expect(GameState.get_inventory_count("food_basic") == old_food, "Rejected food purchase leaves the legacy quantity unchanged")
	var old_cookie: int = GameState.get_inventory_count("cookie_basic")
	_expect(not ShopSystem.can_buy("cookie_basic") and not ShopSystem.buy_item("cookie_basic"), "Legacy cookies are no longer purchasable in the shop")
	_expect(GameState.get_currency("bubble_coin") == 100 and GameState.get_inventory_count("cookie_basic") == old_cookie, "Rejected legacy-cookie purchase changes neither currency nor saved inventory")
	_expect(ShopSystem.buy_item("medicine_basic"), "Shop buys medicine")
	_expect(GameState.get_currency("bubble_coin") == 80, "Medicine purchase costs twenty coins after food and cookie purchases are rejected")
	GameState.set_currency("bubble_coin", 0)
	var medicine_before: int = GameState.get_inventory_count("medicine_basic")
	_expect(not ShopSystem.buy_item("medicine_basic"), "Insufficient coin purchase fails")
	_expect(GameState.get_currency("bubble_coin") == 0, "Currency never falls below zero")
	_expect(GameState.get_inventory_count("medicine_basic") == medicine_before, "Failed purchase changes no inventory")
	var mood_threshold: int = int(GameApp.get_balance_value("passive_coin_mood_threshold"))
	var max_hunger: int = int(GameApp.get_balance_value("max_hunger"))
	for active_pet_id in GameState.get_active_pet_ids():
		var active_pet: Dictionary = GameState.get_pet(active_pet_id)
		active_pet["health"] = "healthy"
		active_pet["hunger"] = max_hunger
		active_pet["mood"] = mood_threshold
		GameState.set_pet(active_pet_id, active_pet)
	var passive_interval: int = int(GameApp.get_balance_value("passive_coin_interval_seconds"))
	var offline_rate: float = float(GameApp.get_balance_value("offline_passive_coin_rate"))
	var offline_cap: int = int(GameApp.get_balance_value("offline_coin_cap_seconds"))
	var passive_amount: int = int(GameApp.get_balance_value("passive_coin_amount"))
	var one_offline_tick_seconds: int = int(ceil(float(passive_interval) / maxf(offline_rate, 0.001)))
	var offline_ticks: int = int(floor(float(min(one_offline_tick_seconds, offline_cap)) * offline_rate / float(max(passive_interval, 1))))
	var eligible_count: int = CoinDropSystem.get_eligible_pet_ids().size()
	_expect(CurrencySystem.calculate_offline_income(one_offline_tick_seconds) == offline_ticks * passive_amount * eligible_count, "Offline income uses the configured half-speed rate for eligible pets")
	var second_pet: Dictionary = GameState.get_pet(GameState.get_pet_ids()[1])
	second_pet["mood"] = maxi(0, mood_threshold - 1)
	GameState.set_pet(str(second_pet.get("pet_id", "")), second_pet)
	eligible_count = CoinDropSystem.get_eligible_pet_ids().size()
	_expect(CurrencySystem.calculate_offline_income(one_offline_tick_seconds) == offline_ticks * passive_amount * eligible_count, "Offline income excludes a pet below the shared mood threshold")
	var capped_ticks: int = int(floor(float(offline_cap) * offline_rate / float(max(passive_interval, 1))))
	_expect(CurrencySystem.calculate_offline_income(offline_cap * 2) == capped_ticks * passive_amount * eligible_count, "Offline income is capped by the configured maximum duration")


func _check_json_round_trip_and_save_load() -> void:
	var original_cookie_count: int = GameState.get_inventory_count("cookie_basic")
	GameState.set_inventory_count("cookie_basic", 17)
	var before_save: Dictionary = GameState.to_save_dict()
	var serialized: String = JSON.stringify(before_save)
	var parsed: Variant = JSON.parse_string(serialized)
	_expect(parsed is Dictionary, "JSON stringify/parse round-trip returns a dictionary")
	if parsed is Dictionary:
		var parsed_schema: Variant = (parsed as Dictionary).get("schema_version")
		_expect(typeof(parsed_schema) == TYPE_FLOAT or typeof(parsed_schema) == TYPE_INT, "JSON schema version parses as a number")
		var prepared: Dictionary = GameState.prepare_data(parsed as Dictionary)
		_expect(bool(prepared.get("ok", false)), "JSON-parsed schema version reloads through prepare_data")
		_expect(int((prepared.get("data", {}) as Dictionary).get("schema_version", -1)) == 2, "JSON round-trip retains supported schema version")
	_expect(SaveManager.save_game(), "Isolated save succeeds")
	var expected: Dictionary = GameState.to_save_dict()
	GameState.reset_to_default()
	_expect(SaveManager.load_game(), "Isolated save reloads")
	var loaded: Dictionary = GameState.to_save_dict()
	var expected_pets: Dictionary = expected.get("pets", {}) as Dictionary
	var loaded_pets: Dictionary = loaded.get("pets", {}) as Dictionary
	_expect(
		JSON.stringify(loaded_pets, "", true, true) == JSON.stringify(expected_pets, "", true, true),
		"Save/load preserves all individual pet records exactly"
	)
	_expect(loaded.get("aquarium", {}) == expected.get("aquarium", {}), "Save/load preserves shared aquarium state")
	_expect(loaded.get("nursery", {}) == expected.get("nursery", {}), "Save/load preserves nursery queue")
	_expect(GameState.get_currency("bubble_coin") == int((expected.get("currency", {}) as Dictionary).get("bubble_coin", -1)), "Save/load preserves shared currency")
	_expect(GameState.get_inventory_count("food_basic") == int((expected.get("inventory", {}) as Dictionary).get("food_basic", -1)), "Save/load preserves shared inventory")
	_expect(GameState.get_inventory_count("cookie_basic") == 17, "Save/load preserves the legacy cookie inventory field")
	var old_save_fixture: Dictionary = GameState.to_save_dict()
	var old_save_inventory: Dictionary = old_save_fixture.get("inventory", {}) as Dictionary
	old_save_inventory["food_basic"] = 17
	old_save_inventory["cookie_basic"] = 23
	var prepared_old_save: Dictionary = GameState.prepare_data(old_save_fixture)
	var prepared_old_data: Dictionary = prepared_old_save.get("data", {}) as Dictionary
	var prepared_old_inventory: Dictionary = prepared_old_data.get("inventory", {}) as Dictionary
	_expect(bool(prepared_old_save.get("ok", false)) and int(prepared_old_inventory.get("food_basic", -1)) == 17, "Save migration preserves an existing food_basic field value")
	_expect(bool(prepared_old_save.get("ok", false)) and int(prepared_old_inventory.get("cookie_basic", -1)) == 23, "Save migration preserves an existing cookie_basic field value")
	GameState.set_inventory_count("cookie_basic", original_cookie_count)
	SaveManager.save_game()
	_expect(SaveManager.get_save_path() == ISOLATED_SAVE_PATH, "Save/load remains isolated from the production path")


func _check_legacy_migration_and_backup_recovery() -> void:
	GameState.reset_to_default()
	var legacy: Dictionary = {
		"schema_version": 1,
		"jellycat": {
			"id": "jc_007",
			"species_id": "normal_jellycat",
			"stage": 2,
			"hunger": 45,
			"mood": 62,
			"cleanliness": 81,
			"health": "healthy",
			"growth_exp": 120
		},
		"care_stats": {
			"touch_growth_exp_today": 4,
			"touch_exp_date": "2026-08-01",
			"last_touch_effect_at": 0.0,
			"touch_cap_notified_date": ""
		},
		"egg": {
			"egg_id": "egg_008",
			"species_id": "normal_jellycat",
			"current_clicks": 3,
			"required_clicks": 10,
			"is_hatched": false
		}
	}
	var legacy_text: String = JSON.stringify(legacy)
	_expect(_write_text(SaveManager.get_save_path(), legacy_text), "Legacy fixture writes inside isolated save path")
	_expect(SaveManager.load_game(), "Legacy save loads and migrates")
	var legacy_pet: Dictionary = GameState.get_pet("jc_007")
	_expect(int(legacy_pet.get("stage", 0)) == 2, "Legacy pet keeps its stage")
	_expect(str(legacy_pet.get("personality_id", "")) == "curious", "Legacy pet receives the fixed curious personality default")
	_expect(GameState.get_nursery_eggs().size() == 2, "Legacy save receives companions up to the three-pet starter target")
	_expect(GameState.get_current_care_stats("jc_007").has("touch_growth_exp_today"), "Legacy care stats migrate onto the pet")
	_expect(FileAccess.file_exists(SaveManager.get_backup_path()), "Successful migration retains the original backup")
	var backup_text: String = _read_text(SaveManager.get_backup_path())
	_expect(backup_text == legacy_text, "Migration backup exactly preserves legacy bytes")
	var migrated_text: String = _read_text(SaveManager.get_save_path())
	var migrated_data: Variant = JSON.parse_string(migrated_text)
	_expect(migrated_data is Dictionary and int((migrated_data as Dictionary).get("schema_version", 0)) == 2, "Migrated file is durably written as schema 2")
	var previous_text: String = migrated_text
	_expect(_write_text(SaveManager.get_save_path() + ".previous", previous_text), "Simulated interrupted transaction writes previous save")
	_remove_file(SaveManager.get_save_path())
	GameState.reset_to_default()
	_expect(SaveManager.load_game(), "Missing main save recovers a valid .previous file")
	_expect(GameState.get_pet("jc_007").size() > 0, "Previous-file recovery restores pet data")
	_expect(not FileAccess.file_exists(SaveManager.get_save_path() + ".previous"), "Recovered previous transaction marker is cleared")


func _check_invalid_save_preservation() -> void:
	var future_text: String = JSON.stringify({"schema_version": 99, "pets": {}})
	_expect(_write_text(SaveManager.get_save_path(), future_text), "Future-version fixture writes to isolated path")
	_expect(not SaveManager.load_game(), "Unknown future schema is rejected")
	_expect(SaveManager.load_blocked, "Unknown future schema blocks writes")
	_expect(_read_text(SaveManager.get_save_path()) == future_text, "Unknown future save is preserved byte-for-byte")
	_expect(not SaveManager.save_game(), "Save cannot overwrite unknown future schema")
	_expect(SaveManager.recover_from_backup(), "Explicit backup recovery restores a supported save")
	_expect(_read_text(SaveManager.get_save_path() + ".corrupt") == future_text, "Explicit recovery keeps the rejected future save for inspection")
	var malformed_text: String = JSON.stringify({"schema_version": 2, "pets": []})
	_expect(_write_text(SaveManager.get_save_path(), malformed_text), "Malformed pets fixture writes to isolated path")
	_expect(not SaveManager.load_game(), "Malformed pets root is rejected")
	_expect(_read_text(SaveManager.get_save_path()) == malformed_text, "Malformed save is never silently replaced")
	var invalid_versions: Array = ["2", true, 2.5, 3, 0, -1]
	for schema_value in invalid_versions:
		var prepared: Dictionary = GameState.prepare_data({"schema_version": schema_value, "pets": {}})
		_expect(not bool(prepared.get("ok", false)), "Invalid schema value is rejected: %s" % str(schema_value))
	var invalid_root: Dictionary = GameState.prepare_data({"schema_version": 2, "pets": "not-a-dictionary"})
	_expect(not bool(invalid_root.get("ok", false)), "Invalid pets root is rejected before defaults can mask it")


func _check_runtime_log() -> void:
	RuntimeLogger.clear()
	for index in range(105):
		RuntimeLogger.log_info("acceptance log %d" % index)
	_expect(RuntimeLogger.get_logs().size() == 100, "Runtime log keeps the latest 100 entries")
	RuntimeLogger.clear()
	_expect(RuntimeLogger.get_logs().is_empty(), "Runtime log clear works")


func _seed_g2_simulation_pets(start_hunger: int, start_mood: int) -> Array[String]:
	SaveManager.reset_save()
	GameState.set_currency("bubble_coin", 0)
	var aquarium: Dictionary = GameState.get_aquarium()
	var pet_count: int = int(aquarium.get("capacity", 0))
	var species_id: String = "normal_jellycat"
	var species: Dictionary = GameApp.get_table("species").get(species_id, {}) as Dictionary
	var evolution: Dictionary = GameApp.get_table("evolution").get(species_id, {}) as Dictionary
	var stages: Array = evolution.get("stages", []) as Array
	var initial_stage: Dictionary = stages[0] as Dictionary if not stages.is_empty() else {}
	var personality_id: String = "curious"
	var pet_ids: Array[String] = []
	for index in range(pet_count):
		var pet_id: String = "g2_sim_%02d" % (index + 1)
		var pet: Dictionary = {
			"pet_id": pet_id,
			"species_id": species_id,
			"nickname": "G2 Simulation %d" % (index + 1),
			"personality_id": personality_id,
			"stage": int(initial_stage.get("stage", 1)),
			"growth_exp": int(initial_stage.get("required_growth_exp", 0)),
			"hunger": start_hunger,
			"mood": start_mood,
			"health": "healthy",
			"care_stats": {}
		}
		var added: bool = GameState.add_pet(pet)
		_expect(added, "G2 simulation seeds pet %s" % pet_id)
		if added:
			pet_ids.append(pet_id)
	_expect(pet_ids.size() == pet_count and pet_ids.size() == GameState.get_active_pet_ids().size(), "G2 simulation uses all configured aquarium slots")
	_expect(pet_ids.size() == 3, "G2 simulation scenario contains the required three pets")
	_expect(SaveManager.save_game(), "G2 simulation fixture is written to the isolated save")
	return pet_ids


func _feed_until_refused(pet_id: String, active_food_limit: int) -> Dictionary:
	var result: Dictionary = {"meal_count": 0, "meal_coins": 0, "peak_active_drops": 0}
	if active_food_limit <= 0:
		return result
	var food: Dictionary = GameApp.get_table("items").get("food_basic", {}) as Dictionary
	var meal_coin_base: int = int(GameApp.get_balance_value("meal_coin_base_value"))
	var active_drops: int = 0
	while not CareSystem.is_food_refused(GameState.get_pet(pet_id)):
		if active_drops >= active_food_limit:
			break
		var pet_before: Dictionary = GameState.get_pet(pet_id)
		var hunger_before: int = int(pet_before.get("hunger", 0))
		var stage: int = int(pet_before.get("stage", 1))
		active_drops += 1
		result["peak_active_drops"] = maxi(int(result["peak_active_drops"]), active_drops)
		var fed: bool = CareSystem.feed_food(pet_id, false)
		active_drops -= 1
		if not fed:
			break
		var hunger_after: int = int(GameState.get_pet(pet_id).get("hunger", 0))
		if hunger_after <= hunger_before:
			break
		var meal_value: int = meal_coin_base + stage
		result["meal_count"] = int(result["meal_count"]) + 1
		result["meal_coins"] = int(result["meal_coins"]) + meal_value
		CurrencySystem.add_coin(meal_value, "G2 simulated meal pickup")
	return result


func _check_g2_care_regressions() -> void:
	var max_hunger: int = int(GameApp.get_balance_value("max_hunger"))
	var max_mood: int = int(GameApp.get_balance_value("max_mood"))
	var hunger_threshold: int = int(GameApp.get_balance_value("food_refusal_hunger_threshold"))
	var hungry_max: int = int(GameApp.get_balance_value("hungry_hunger_max"))
	var seconds_per_minute: int = int(GameApp.get_balance_value("seconds_per_minute"))
	var hunger_decay: int = int(GameApp.get_balance_value("hunger_decay_per_minute"))
	var hungry_mood_decay: int = int(GameApp.get_balance_value("mood_decay_hungry_per_min"))
	var starving_mood_decay: int = int(GameApp.get_balance_value("mood_decay_starving_per_min"))
	var pet_ids: Array[String] = _seed_g2_simulation_pets(max_hunger, max_mood)
	if pet_ids.is_empty():
		return
	var pet_id: String = pet_ids[0]
	var pet: Dictionary = GameState.get_pet(pet_id)
	pet["hunger"] = 0
	pet["mood"] = max_mood
	pet["health"] = "healthy"
	GameState.set_pet(pet_id, pet)
	var ten_test_minutes: int = 10
	CareSystem.apply_online_care_decay(ten_test_minutes * seconds_per_minute)
	var starving_after: Dictionary = GameState.get_pet(pet_id)
	var expected_starving_mood: int = maxi(0, max_mood - ten_test_minutes * starving_mood_decay)
	_expect(int(starving_after.get("hunger", -1)) == 0 and int(starving_after.get("mood", -1)) == expected_starving_mood, "Online starving decay respects the configured rate and clamps at zero")
	_expect(str(starving_after.get("health", "")) == "healthy" and not GameState.get_pet(pet_id).is_empty(), "Starvation does not cause illness or death")
	pet = GameState.get_pet(pet_id)
	pet["hunger"] = max_hunger
	pet["mood"] = max_mood
	GameState.set_pet(pet_id, pet)
	var four_test_minutes: int = 4
	CareSystem.apply_online_care_decay(four_test_minutes * seconds_per_minute)
	var four_minute_after: Dictionary = GameState.get_pet(pet_id)
	var expected_four_minute_hunger: int = maxi(0, max_hunger - four_test_minutes * hunger_decay)
	_expect(int(four_minute_after.get("hunger", -1)) == expected_four_minute_hunger, "Time-injected four-minute care decay reaches the configured hunger value")
	pet = GameState.get_pet(pet_id)
	pet["hunger"] = hungry_max
	pet["mood"] = max_mood
	GameState.set_pet(pet_id, pet)
	var hungry_first_minute_hunger: int = -1
	for minute_index in range(ten_test_minutes):
		CareSystem.apply_online_care_decay(seconds_per_minute)
		pet = GameState.get_pet(pet_id)
		if minute_index == 0:
			hungry_first_minute_hunger = int(pet.get("hunger", -1))
		pet["hunger"] = hungry_max
		GameState.set_pet(pet_id, pet)
	var hungry_after: Dictionary = GameState.get_pet(pet_id)
	var expected_hungry_mood: int = maxi(0, max_mood - ten_test_minutes * hungry_mood_decay)
	_expect(int(hungry_after.get("mood", -1)) == expected_hungry_mood, "Maintained hungry-state test loses the configured mood per minute")
	var expected_hunger_after_one_minute: int = maxi(0, hungry_max - hunger_decay)
	_expect(hungry_first_minute_hunger == expected_hunger_after_one_minute, "Hungry state loses the configured hunger per minute")
	var food: Dictionary = GameApp.get_table("items").get("food_basic", {}) as Dictionary
	var food_hunger_add: int = int(food.get("hunger_add", 0))
	var food_exp_add: int = int(food.get("growth_exp_add", 0))
	pet = GameState.get_pet(pet_id)
	pet["hunger"] = hunger_threshold
	pet["growth_exp"] = 0
	GameState.set_pet(pet_id, pet)
	_expect(CareSystem.feed_food(pet_id), "Food is accepted at the configured refusal threshold")
	var accepted_food_pet: Dictionary = GameState.get_pet(pet_id)
	_expect(int(accepted_food_pet.get("hunger", -1)) == mini(max_hunger, hunger_threshold + food_hunger_add) and int(accepted_food_pet.get("growth_exp", -1)) == food_exp_add, "Accepted food grants configured hunger and EXP exactly once")
	pet = GameState.get_pet(pet_id)
	pet["hunger"] = mini(max_hunger, hunger_threshold + 1)
	pet["growth_exp"] = 0
	GameState.set_pet(pet_id, pet)
	var refused_before: Dictionary = GameState.get_pet(pet_id)
	_expect(not CareSystem.feed_food(pet_id), "Food is refused above the configured threshold")
	_expect(GameState.get_pet(pet_id) == refused_before, "Refused food changes no pet stats")
	if hunger_threshold < max_hunger:
		pet = GameState.get_pet(pet_id)
		pet["hunger"] = hunger_threshold
		GameState.set_pet(pet_id, pet)
		var food_drop: Dictionary = FoodDropSystem.drop_food(Vector2.ZERO)
		var food_token: String = str(food_drop.get("token_id", ""))
		var meal_stage: int = int(GameState.get_pet(pet_id).get("stage", 1))
		var expected_meal_coin: int = int(GameApp.get_balance_value("meal_coin_base_value")) + meal_stage
		var coin_before: int = GameState.get_currency("bubble_coin")
		var consumed: bool = FoodDropSystem.consume_food(food_token, pet_id, Vector2.ZERO)
		var meal_drop: Dictionary = CoinDropSystem.get_meal_coin_drop(food_token)
		_expect(consumed and food_drop.is_empty() == false and GameState.get_food_drops().is_empty(), "Meal settlement consumes its food token exactly once")
		_expect(str(meal_drop.get("source", "")) == "meal" and int(meal_drop.get("value", 0)) == expected_meal_coin, "Meal bubble value uses configured base plus current stage")
		var coin_token: String = str(meal_drop.get("token_id", ""))
		var pending_saved: bool = SaveManager.save_game()
		GameState.reset_to_default()
		var pending_reloaded: bool = pending_saved and SaveManager.load_game()
		var restored_meal_drop: Dictionary = CoinDropSystem.get_meal_coin_drop(food_token)
		_expect(pending_reloaded and str(restored_meal_drop.get("token_id", "")) == coin_token and GameState.get_currency("bubble_coin") == coin_before, "Uncollected meal bubble and uncredited wallet survive restart")
		if pending_reloaded and not coin_token.is_empty():
			var collected: Dictionary = CoinDropSystem.collect_coin(coin_token, false)
			var currency_after_collection: int = GameState.get_currency("bubble_coin")
			var duplicate_collection: Dictionary = CoinDropSystem.collect_coin(coin_token, false)
			_expect(not collected.is_empty() and currency_after_collection == coin_before + expected_meal_coin, "Manual pickup credits the meal bubble exactly once")
			_expect(duplicate_collection.is_empty() and GameState.get_currency("bubble_coin") == currency_after_collection, "Replaying a collected meal token cannot credit coins twice")
			var settled_saved: bool = SaveManager.save_game()
			GameState.reset_to_default()
			var settled_reloaded: bool = settled_saved and SaveManager.load_game()
			_expect(settled_reloaded and GameState.get_coin_drops().is_empty() and GameState.get_currency("bubble_coin") == currency_after_collection, "Settled meal coin stays credited once with no bubble after restart")
			if not settled_reloaded:
				pet_ids = _seed_g2_simulation_pets(max_hunger, max_mood)
				pet_id = pet_ids[0] if not pet_ids.is_empty() else ""
		else:
			pet_ids = _seed_g2_simulation_pets(max_hunger, max_mood)
			pet_id = pet_ids[0] if not pet_ids.is_empty() else ""
	var passive_interval: int = int(GameApp.get_balance_value("passive_coin_interval_seconds"))
	var passive_amount: int = int(GameApp.get_balance_value("passive_coin_amount"))
	for active_pet_id in pet_ids:
		var active_pet: Dictionary = GameState.get_pet(active_pet_id)
		active_pet["health"] = "healthy"
		active_pet["hunger"] = max_hunger
		active_pet["mood"] = int(GameApp.get_balance_value("passive_coin_mood_threshold"))
		GameState.set_pet(active_pet_id, active_pet)
	var eligible_count: int = CoinDropSystem.get_eligible_pet_ids().size()
	_expect(CurrencySystem.calculate_passive_income(passive_interval - 1) == 0, "Online passive coins wait for the configured interval")
	_expect(CurrencySystem.calculate_passive_income(passive_interval) == eligible_count * passive_amount, "Online passive income uses one configured amount per eligible pet")
	var hunger_floor: int = int(GameApp.get_balance_value("offline_hunger_floor"))
	var mood_floor: int = int(GameApp.get_balance_value("offline_mood_floor"))
	var offline_test_days: int = 10
	var offline_snapshot: Dictionary = GameState.to_save_dict().duplicate(true)
	var previous_time_scale: int = TimeManager.get_time_scale()
	var sick_threshold: int = int(GameApp.get_balance_value("sick_cleanliness_threshold", 0))
	var cleanliness_floor: int = int(GameApp.get_balance_value("offline_cleanliness_floor", sick_threshold + 1))
	GameState.set_aquarium_cleanliness(int(GameApp.get_balance_value("max_cleanliness")))
	for active_pet_id in pet_ids:
		var active_pet: Dictionary = GameState.get_pet(active_pet_id)
		active_pet["hunger"] = max_hunger
		active_pet["mood"] = max_mood
		active_pet["health"] = "healthy"
		GameState.set_pet(active_pet_id, active_pet)
	TimeManager.set_time_scale(60)
	CareSystem.apply_offline_care_decay(offline_test_days * TimeManager.SECONDS_PER_DAY)
	var offline_floors_hold: bool = true
	var offline_health_unchanged: bool = true
	var offline_cleanliness_is_floor: bool = int(GameState.get_aquarium().get("cleanliness", -1)) == cleanliness_floor
	for active_pet_id in pet_ids:
		var offline_pet: Dictionary = GameState.get_pet(active_pet_id)
		offline_floors_hold = offline_floors_hold and int(offline_pet.get("hunger", -1)) >= hunger_floor and int(offline_pet.get("mood", -1)) >= mood_floor
		offline_health_unchanged = offline_health_unchanged and str(offline_pet.get("health", "")) == "healthy"
	print("RUNTIME_OFFLINE_10D days=%d cleanliness=%d floor=%d threshold=%d floors_hold=%s healthy=%s time_scale=%d" % [offline_test_days, int(GameState.get_aquarium().get("cleanliness", -1)), cleanliness_floor, sick_threshold, str(offline_floors_hold), str(offline_health_unchanged), TimeManager.get_time_scale()])
	_expect(offline_floors_hold, "Offline hunger and mood remain above their configured floors")
	_expect(offline_test_days == 10 and offline_health_unchanged and offline_cleanliness_is_floor and cleanliness_floor > sick_threshold, "Ten offline days clamp water above the sickness threshold without making any healthy pet sick, even with ×60 active")
	var old_sick_pet_id: String = pet_ids[0]
	var old_sick_pet: Dictionary = GameState.get_pet(old_sick_pet_id)
	old_sick_pet["health"] = "sick"
	GameState.set_pet(old_sick_pet_id, old_sick_pet)
	CareSystem.apply_offline_care_decay(10 * TimeManager.SECONDS_PER_DAY)
	_expect(str(GameState.get_pet(old_sick_pet_id).get("health", "")) == "sick", "Offline decay does not automatically cure an already-sick saved pet")
	for active_pet_id in pet_ids:
		var healthy_pet: Dictionary = GameState.get_pet(active_pet_id)
		healthy_pet["health"] = "healthy"
		GameState.set_pet(active_pet_id, healthy_pet)
	GameState.set_aquarium_cleanliness(sick_threshold)
	CareSystem.apply_online_care_decay(1)
	var online_sickness_applied: bool = true
	for active_pet_id in pet_ids:
		online_sickness_applied = online_sickness_applied and str(GameState.get_pet(active_pet_id).get("health", "")) == "sick"
	_expect(online_sickness_applied, "Online dirty-water sickness still applies at the configured threshold")
	TimeManager.set_time_scale(previous_time_scale)
	GameState.set_data(offline_snapshot)


func _check_day1_simulation() -> void:
	var max_hunger: int = int(GameApp.get_balance_value("max_hunger"))
	var start_mood: int = int(GameApp.get_balance_value("passive_coin_mood_threshold"))
	var pet_ids: Array[String] = _seed_g2_simulation_pets(max_hunger, start_mood)
	if pet_ids.is_empty():
		return
	var seconds_per_minute: int = int(GameApp.get_balance_value("seconds_per_minute"))
	var seconds_per_hour: int = seconds_per_minute * 60
	var online_minutes: int = 3
	var touches_per_session: int = 5
	var touch_cooldown: float = float(GameApp.get_balance_value("touch_cooldown_seconds"))
	var passive_interval: int = max(int(GameApp.get_balance_value("passive_coin_interval_seconds")), 1)
	var active_food_limit: int = GameState.get_max_active_food_drops()
	var session_hours: Array[int] = [8, 11, 14, 17, 20, 23]
	var simulation_start: float = Time.get_unix_time_from_system()
	var previous_session_end_seconds: int = 0
	var source_totals: Dictionary = {"meal": 0, "online_auto": 0, "offline": 0, "evolution": 0}
	var pet_source_totals: Dictionary = {}
	for pet_id in pet_ids:
		pet_source_totals[pet_id] = {"meal": 0, "online_auto": 0, "offline": 0, "evolution": 0}
	var csv_lines: PackedStringArray = PackedStringArray()
	csv_lines.append("checkpoint,clock,pet_id,growth_exp,stage,mood,hunger,meal_coins_session,online_auto_coins_session,offline_coins_since_previous,evolution_bonus_session,meal_coins_total,online_auto_coins_total,offline_coins_total,evolution_bonus_total,total_coins")
	for session_index in range(session_hours.size()):
		var session_start_seconds: int = (session_hours[session_index] - session_hours[0]) * seconds_per_hour
		var offline_income_this_session: int = 0
		var offline_coins_by_pet: Dictionary = {}
		for pet_id in pet_ids:
			offline_coins_by_pet[pet_id] = 0
		if session_index > 0:
			var offline_elapsed: int = session_start_seconds - previous_session_end_seconds
			offline_income_this_session = CurrencySystem.calculate_offline_income(offline_elapsed)
			CurrencySystem.add_coin(offline_income_this_session, "G2 day-one offline income")
			source_totals["offline"] = int(source_totals["offline"]) + offline_income_this_session
			var session_offline_cap: int = int(GameApp.get_balance_value("offline_coin_cap_seconds"))
			var session_offline_rate: float = float(GameApp.get_balance_value("offline_passive_coin_rate"))
			var session_passive_amount: int = int(GameApp.get_balance_value("passive_coin_amount"))
			var offline_ticks: int = int(floor(float(min(offline_elapsed, session_offline_cap)) * session_offline_rate / float(passive_interval)))
			for eligible_pet_id in CoinDropSystem.get_eligible_pet_ids():
				var offline_pet_sources: Dictionary = pet_source_totals[eligible_pet_id] as Dictionary
				var pet_offline_income: int = offline_ticks * session_passive_amount
				offline_pet_sources["offline"] = int(offline_pet_sources["offline"]) + pet_offline_income
				pet_source_totals[eligible_pet_id] = offline_pet_sources
				offline_coins_by_pet[eligible_pet_id] = pet_offline_income
			CareSystem.apply_offline_care_decay(offline_elapsed)
		var meal_coins_this_session: int = 0
		var online_coins_this_session: int = 0
		var evolution_coins_this_session: int = 0
		var meal_coins_by_pet: Dictionary = {}
		var online_coins_by_pet: Dictionary = {}
		var evolution_coins_by_pet: Dictionary = {}
		for pet_id in pet_ids:
			meal_coins_by_pet[pet_id] = 0
			online_coins_by_pet[pet_id] = 0
			evolution_coins_by_pet[pet_id] = 0
			var feeding: Dictionary = _feed_until_refused(pet_id, active_food_limit)
			var pet_meal_coins: int = int(feeding.get("meal_coins", 0))
			meal_coins_this_session += pet_meal_coins
			meal_coins_by_pet[pet_id] = pet_meal_coins
			var meal_pet_sources: Dictionary = pet_source_totals[pet_id] as Dictionary
			meal_pet_sources["meal"] = int(meal_pet_sources["meal"]) + pet_meal_coins
			pet_source_totals[pet_id] = meal_pet_sources
			_expect(int(feeding.get("peak_active_drops", 0)) <= active_food_limit, "Day-one simulated feed respects the configured onscreen-drop limit")
		var touch_spacing: float = maxf(touch_cooldown + 0.001, 0.001)
		for touch_index in range(touches_per_session):
			var touch_time: float = simulation_start + float(session_start_seconds) + float(touch_index + 1) * touch_spacing
			for pet_id in pet_ids:
				CareSystem.touch_pet(pet_id, touch_time)
		var online_passive_elapsed: int = 0
		for _minute in range(online_minutes):
			CareSystem.apply_online_care_decay(seconds_per_minute)
			online_passive_elapsed += seconds_per_minute
			while online_passive_elapsed >= passive_interval:
				online_passive_elapsed -= passive_interval
				var passive_income: int = CurrencySystem.calculate_passive_income(passive_interval)
				CurrencySystem.add_coin(passive_income, "G2 day-one online passive income")
				online_coins_this_session += passive_income
				var eligible_online_pets: Array[String] = CoinDropSystem.get_eligible_pet_ids()
				var per_pet_online_income: int = int(GameApp.get_balance_value("passive_coin_amount"))
				for eligible_pet_id in eligible_online_pets:
					var online_pet_sources: Dictionary = pet_source_totals[eligible_pet_id] as Dictionary
					online_pet_sources["online_auto"] = int(online_pet_sources["online_auto"]) + per_pet_online_income
					pet_source_totals[eligible_pet_id] = online_pet_sources
					online_coins_by_pet[eligible_pet_id] = int(online_coins_by_pet[eligible_pet_id]) + per_pet_online_income
		for pet_id in pet_ids:
			var pet: Dictionary = GameState.get_pet(pet_id)
			var species: Dictionary = GameApp.get_table("species").get(str(pet.get("species_id", "normal_jellycat")), {}) as Dictionary
			var max_stage: int = int(species.get("max_stage", 0))
			while int(pet.get("stage", 0)) < max_stage and EvolutionSystem.can_evolve(pet_id):
				var currency_before: int = GameState.get_currency("bubble_coin")
				var growth_before: int = int(pet.get("growth_exp", 0))
				if not EvolutionSystem.evolve(pet_id):
					break
				pet = GameState.get_pet(pet_id)
				var bonus: int = GameState.get_currency("bubble_coin") - currency_before
				evolution_coins_this_session += bonus
				evolution_coins_by_pet[pet_id] = int(evolution_coins_by_pet[pet_id]) + bonus
				var evolution_pet_sources: Dictionary = pet_source_totals[pet_id] as Dictionary
				evolution_pet_sources["evolution"] = int(evolution_pet_sources["evolution"]) + bonus
				pet_source_totals[pet_id] = evolution_pet_sources
				_expect(int(pet.get("growth_exp", -1)) == growth_before, "Day-one evolution preserves cumulative EXP")
		source_totals["meal"] = int(source_totals["meal"]) + meal_coins_this_session
		source_totals["online_auto"] = int(source_totals["online_auto"]) + online_coins_this_session
		source_totals["evolution"] = int(source_totals["evolution"]) + evolution_coins_this_session
		for pet_id in pet_ids:
			var pet: Dictionary = GameState.get_pet(pet_id)
			var pet_totals: Dictionary = pet_source_totals[pet_id] as Dictionary
			csv_lines.append("session_%d,%02d:00,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d" % [
				session_index + 1,
				session_hours[session_index],
				pet_id,
				int(pet.get("growth_exp", 0)),
				int(pet.get("stage", 0)),
				int(pet.get("mood", 0)),
				int(pet.get("hunger", 0)),
				int(meal_coins_by_pet[pet_id]),
				int(online_coins_by_pet[pet_id]),
				int(offline_coins_by_pet[pet_id]),
				int(evolution_coins_by_pet[pet_id]),
				int(pet_totals["meal"]),
				int(pet_totals["online_auto"]),
				int(pet_totals["offline"]),
				int(pet_totals["evolution"]),
				GameState.get_currency("bubble_coin")
			])
		previous_session_end_seconds = session_start_seconds + online_minutes * seconds_per_minute
	var day1_stage_summary: PackedStringArray = PackedStringArray()
	var day1_all_reached_reference_stage: bool = true
	for pet_id in pet_ids:
		var pet: Dictionary = GameState.get_pet(pet_id)
		var pet_stage: int = int(pet.get("stage", 0))
		day1_stage_summary.append("%s:%d" % [pet_id, pet_stage])
		day1_all_reached_reference_stage = day1_all_reached_reference_stage and pet_stage >= 2
	print("G2_DAY1_V1_COMPARE reference_design_v1_section_7_stage=2_all_pets coins_about=400 actual_23_03_coin_total=%d actual_23_03_stages=%s all_at_least_stage_2=%s" % [GameState.get_currency("bubble_coin"), ",".join(day1_stage_summary), str(day1_all_reached_reference_stage)])
	var day_seconds: int = TimeManager.SECONDS_PER_DAY
	var final_offline_seconds: int = day_seconds - previous_session_end_seconds
	var final_offline_income: int = CurrencySystem.calculate_offline_income(final_offline_seconds)
	CurrencySystem.add_coin(final_offline_income, "G2 day-one final offline income")
	source_totals["offline"] = int(source_totals["offline"]) + final_offline_income
	var final_offline_cap: int = int(GameApp.get_balance_value("offline_coin_cap_seconds"))
	var final_offline_rate: float = float(GameApp.get_balance_value("offline_passive_coin_rate"))
	var final_passive_amount: int = int(GameApp.get_balance_value("passive_coin_amount"))
	var final_offline_ticks: int = int(floor(float(min(final_offline_seconds, final_offline_cap)) * final_offline_rate / float(passive_interval)))
	var final_offline_by_pet: Dictionary = {}
	for pet_id in pet_ids:
		final_offline_by_pet[pet_id] = 0
	for eligible_pet_id in CoinDropSystem.get_eligible_pet_ids():
		var final_pet_sources: Dictionary = pet_source_totals[eligible_pet_id] as Dictionary
		var pet_offline_income: int = final_offline_ticks * final_passive_amount
		final_pet_sources["offline"] = int(final_pet_sources["offline"]) + pet_offline_income
		pet_source_totals[eligible_pet_id] = final_pet_sources
		final_offline_by_pet[eligible_pet_id] = pet_offline_income
	CareSystem.apply_offline_care_decay(final_offline_seconds)
	for pet_id in pet_ids:
		var pet: Dictionary = GameState.get_pet(pet_id)
		var pet_totals: Dictionary = pet_source_totals[pet_id] as Dictionary
		csv_lines.append("day2_return,08:00,%s,%d,%d,%d,%d,0,0,%d,0,%d,%d,%d,%d,%d" % [
			pet_id,
			int(pet.get("growth_exp", 0)),
			int(pet.get("stage", 0)),
			int(pet.get("mood", 0)),
			int(pet.get("hunger", 0)),
			int(final_offline_by_pet[pet_id]),
			int(pet_totals["meal"]),
			int(pet_totals["online_auto"]),
			int(pet_totals["offline"]),
			int(pet_totals["evolution"]),
			GameState.get_currency("bubble_coin")
		])
	var csv_path: String = "user://g2_day1_simulation.csv"
	_expect(_write_text(csv_path, "\n".join(csv_lines) + "\n"), "Day-one simulation writes its per-session CSV")
	print("G2_DAY1_SIMULATION_CSV=%s" % ProjectSettings.globalize_path(csv_path))
	print("G2_DAY1_TOTALS meal=%d online_auto=%d offline=%d evolution=%d total=%d" % [int(source_totals["meal"]), int(source_totals["online_auto"]), int(source_totals["offline"]), int(source_totals["evolution"]), GameState.get_currency("bubble_coin")])


func _check_one_hour_progression() -> void:
	var max_hunger: int = int(GameApp.get_balance_value("max_hunger"))
	var start_mood: int = int(GameApp.get_balance_value("passive_coin_mood_threshold"))
	var pet_ids: Array[String] = _seed_g2_simulation_pets(max_hunger, start_mood)
	if pet_ids.is_empty():
		return
	var species_id: String = str(GameState.get_pet(pet_ids[0]).get("species_id", "normal_jellycat"))
	var species: Dictionary = GameApp.get_table("species").get(species_id, {}) as Dictionary
	var evolution: Dictionary = GameApp.get_table("evolution").get(species_id, {}) as Dictionary
	var stages: Array = evolution.get("stages", []) as Array
	var max_stage: int = int(species.get("max_stage", 0))
	var seconds_per_minute: int = int(GameApp.get_balance_value("seconds_per_minute"))
	var total_minutes: int = 60
	var active_food_limit: int = GameState.get_max_active_food_drops()
	var passive_interval: int = max(int(GameApp.get_balance_value("passive_coin_interval_seconds")), 1)
	var touch_cooldown: float = float(GameApp.get_balance_value("touch_cooldown_seconds"))
	_expect(touch_cooldown <= float(seconds_per_minute), "Configured touch cooldown permits the per-minute one-hour simulation")
	var simulation_start: float = Time.get_unix_time_from_system()
	var passive_elapsed: int = 0
	var source_totals: Dictionary = {"meal": 0, "passive": 0, "evolution": 0}
	var pet_source_totals: Dictionary = {}
	var stage_times: Dictionary = {}
	var stage_sequence: Dictionary = {}
	var expected_evolution_stages: Array[int] = []
	for stage_index in range(1, stages.size()):
		expected_evolution_stages.append(int((stages[stage_index] as Dictionary).get("stage", 0)))
	var actors: Dictionary = {}
	var actor_scene: PackedScene = load("res://scenes/pet/jellycat_actor.tscn") as PackedScene
	_expect(actor_scene != null, "One-hour test loads the production JellyCat actor scene")
	if actor_scene == null:
		return
	for pet_id in pet_ids:
		pet_source_totals[pet_id] = {"meal": 0, "passive": 0, "evolution": 0}
		var actor: Node2D = actor_scene.instantiate() as Node2D
		var actor_bound: bool = bool(actor.call("set_pet_id", pet_id))
		_expect(actor_bound, "One-hour actor binds to %s" % pet_id)
		add_child(actor)
		actor.call("refresh_pet")
		actors[pet_id] = actor
		stage_times[pet_id] = {}
		stage_sequence[pet_id] = []
		var sprite: Sprite2D = actor.get_node("%Sprite") as Sprite2D
		var expected_path: String = "res://assets/jellycats/%s/stages/stage_%d.png" % [species_id, int(GameState.get_pet(pet_id).get("stage", 1))]
		_expect(sprite != null and sprite.texture != null and sprite.texture.resource_path == expected_path, "Stage-one actor uses its frozen stage image")
	var csv_lines: PackedStringArray = PackedStringArray()
	csv_lines.append("minute,pet_id,growth_exp,stage,mood,hunger,meal_coins_total,passive_coin_total,evolution_bonus_total,total_coins")
	var peak_active_food_drops: int = 0
	for minute in range(1, total_minutes + 1):
		CareSystem.apply_online_care_decay(seconds_per_minute)
		for pet_id in pet_ids:
			var feeding: Dictionary = _feed_until_refused(pet_id, active_food_limit)
			var pet_meal_coins: int = int(feeding.get("meal_coins", 0))
			source_totals["meal"] = int(source_totals["meal"]) + pet_meal_coins
			var meal_pet_totals: Dictionary = pet_source_totals[pet_id] as Dictionary
			meal_pet_totals["meal"] = int(meal_pet_totals["meal"]) + pet_meal_coins
			pet_source_totals[pet_id] = meal_pet_totals
			peak_active_food_drops = maxi(peak_active_food_drops, int(feeding.get("peak_active_drops", 0)))
			var touch_time: float = simulation_start + float(minute * seconds_per_minute)
			var pet_before_touch: Dictionary = GameState.get_pet(pet_id)
			var care_before_touch: Dictionary = GameState.get_current_care_stats(pet_id)
			var touch_cap: int = int(GameApp.get_balance_value("touch_growth_exp_cap"))
			var touch_should_change_state: bool = int(pet_before_touch.get("mood", 0)) < int(GameApp.get_balance_value("max_mood")) or int(care_before_touch.get("touch_growth_exp_hour", 0)) < touch_cap
			var touch_changed_state: bool = CareSystem.touch_pet(pet_id, touch_time)
			_expect(touch_changed_state == touch_should_change_state, "One-hour test applies or caps the configured per-minute touch for %s at minute %d" % [pet_id, minute])
			var pet: Dictionary = GameState.get_pet(pet_id)
			while int(pet.get("stage", 0)) < max_stage and EvolutionSystem.can_evolve(pet_id):
				var next_stage_data: Dictionary = EvolutionSystem.get_next_stage_data(pet_id)
				var next_stage: int = int(next_stage_data.get("stage", 0))
				var growth_before: int = int(pet.get("growth_exp", 0))
				var coins_before: int = GameState.get_currency("bubble_coin")
				var evolved: bool = EvolutionSystem.evolve(pet_id)
				_expect(evolved, "%s evolves to stage %d at minute %d" % [pet_id, next_stage, minute])
				if not evolved:
					break
				pet = GameState.get_pet(pet_id)
				var expected_bonus_table: Dictionary = GameApp.get_balance_value("evolution_coin_bonus", {}) as Dictionary
				var expected_bonus: int = int(expected_bonus_table.get(str(next_stage), 0))
				var actual_bonus: int = GameState.get_currency("bubble_coin") - coins_before
				_expect(actual_bonus == expected_bonus and int(pet.get("growth_exp", -1)) == growth_before, "Evolution reward is paid once and cumulative EXP is preserved")
				source_totals["evolution"] = int(source_totals["evolution"]) + actual_bonus
				var evolution_pet_totals: Dictionary = pet_source_totals[pet_id] as Dictionary
				evolution_pet_totals["evolution"] = int(evolution_pet_totals["evolution"]) + actual_bonus
				pet_source_totals[pet_id] = evolution_pet_totals
				var sequence: Array = stage_sequence[pet_id] as Array
				sequence.append(next_stage)
				stage_sequence[pet_id] = sequence
				var pet_stage_times: Dictionary = stage_times[pet_id] as Dictionary
				pet_stage_times[str(next_stage)] = minute
				stage_times[pet_id] = pet_stage_times
				var actor: Node2D = actors[pet_id] as Node2D
				actor.call("refresh_pet")
				var sprite: Sprite2D = actor.get_node("%Sprite") as Sprite2D
				var texture_path: String = "res://assets/jellycats/%s/stages/stage_%d.png" % [species_id, next_stage]
				_expect(ResourceLoader.exists(texture_path) and sprite != null and sprite.texture != null and sprite.texture.resource_path == texture_path and int(actor.get("current_stage")) == next_stage, "Evolution switches %s to the frozen stage-%d image" % [pet_id, next_stage])
				var new_exp: int = int(pet.get("growth_exp", 0))
				_expect(new_exp == growth_before, "Stage transition does not reset cumulative growth EXP")
		passive_elapsed += seconds_per_minute
		while passive_elapsed >= passive_interval:
			passive_elapsed -= passive_interval
			var passive_income: int = CurrencySystem.calculate_passive_income(passive_interval)
			CurrencySystem.add_coin(passive_income, "G2 one-hour passive pickup")
			source_totals["passive"] = int(source_totals["passive"]) + passive_income
			var eligible_pet_ids: Array[String] = CoinDropSystem.get_eligible_pet_ids()
			var passive_per_pet: int = int(GameApp.get_balance_value("passive_coin_amount"))
			for eligible_pet_id in eligible_pet_ids:
				var passive_pet_totals: Dictionary = pet_source_totals[eligible_pet_id] as Dictionary
				passive_pet_totals["passive"] = int(passive_pet_totals["passive"]) + passive_per_pet
				pet_source_totals[eligible_pet_id] = passive_pet_totals
		for pet_id in pet_ids:
			var pet: Dictionary = GameState.get_pet(pet_id)
			var pet_totals: Dictionary = pet_source_totals[pet_id] as Dictionary
			csv_lines.append("%d,%s,%d,%d,%d,%d,%d,%d,%d,%d" % [
				minute,
				pet_id,
				int(pet.get("growth_exp", 0)),
				int(pet.get("stage", 0)),
				int(pet.get("mood", 0)),
				int(pet.get("hunger", 0)),
				int(pet_totals["meal"]),
				int(pet_totals["passive"]),
				int(pet_totals["evolution"]),
				GameState.get_currency("bubble_coin")
			])
	_expect(peak_active_food_drops <= active_food_limit, "One-hour feeding never exceeds the configured active-food screen limit")
	var all_evolved: bool = true
	for pet_id in pet_ids:
		var final_pet: Dictionary = GameState.get_pet(pet_id)
		var sequence: Array = stage_sequence[pet_id] as Array
		var reached_before_deadline: bool = sequence == expected_evolution_stages
		var care_stats: Dictionary = GameState.get_current_care_stats(pet_id)
		_expect(int(care_stats.get("touch_growth_exp_hour", 0)) == int(GameApp.get_balance_value("touch_growth_exp_cap")), "%s reaches the configured touch EXP cap in the one-hour test" % pet_id)
		var pet_stage_times: Dictionary = stage_times[pet_id] as Dictionary
		for required_stage in expected_evolution_stages:
			reached_before_deadline = reached_before_deadline and pet_stage_times.has(str(required_stage)) and int(pet_stage_times[str(required_stage)]) <= total_minutes
		all_evolved = all_evolved and int(final_pet.get("stage", 0)) == max_stage and reached_before_deadline
		_expect(int(final_pet.get("stage", 0)) == max_stage and reached_before_deadline, "%s reaches every configured stage through maximum by the one-hour deadline" % pet_id)
	_expect(all_evolved, "All three pets reach the maximum configured stage within 60 simulated minutes")
	var first_pet_id: String = pet_ids[0]
	var first_pet_before_duplicate: Dictionary = GameState.get_pet(first_pet_id)
	var coins_before_duplicate: int = GameState.get_currency("bubble_coin")
	_expect(not EvolutionSystem.evolve(first_pet_id) and GameState.get_currency("bubble_coin") == coins_before_duplicate and int(GameState.get_pet(first_pet_id).get("stage", 0)) == int(first_pet_before_duplicate.get("stage", 0)), "A repeated max-stage evolution attempt grants no duplicate reward")
	var csv_path: String = "user://g2_one_hour_progression.csv"
	_expect(_write_text(csv_path, "\n".join(csv_lines) + "\n"), "One-hour progression writes the per-minute CSV")
	print("G2_ONE_HOUR_PROGRESS_CSV=%s" % ProjectSettings.globalize_path(csv_path))
	print("G2_ONE_HOUR_TOTALS meal=%d passive=%d evolution=%d total=%d" % [int(source_totals["meal"]), int(source_totals["passive"]), int(source_totals["evolution"]), GameState.get_currency("bubble_coin")])
	var before_reload: Dictionary = {}
	for pet_id in pet_ids:
		var pet: Dictionary = GameState.get_pet(pet_id)
		before_reload[pet_id] = {"stage": int(pet.get("stage", 0)), "growth_exp": int(pet.get("growth_exp", 0))}
	_expect(SaveManager.save_game(), "One-hour evolved state saves before reload")
	GameState.reset_to_default()
	_expect(SaveManager.load_game(), "One-hour evolved state reloads from the isolated save")
	for pet_id in pet_ids:
		var expected_state: Dictionary = before_reload[pet_id] as Dictionary
		var loaded_pet: Dictionary = GameState.get_pet(pet_id)
		_expect(int(loaded_pet.get("stage", -1)) == int(expected_state.get("stage", -2)) and int(loaded_pet.get("growth_exp", -1)) == int(expected_state.get("growth_exp", -2)), "Reload preserves %s stage and cumulative EXP" % pet_id)
		var actor: Node2D = actors[pet_id] as Node2D
		actor.call("refresh_pet")
		var sprite: Sprite2D = actor.get_node("%Sprite") as Sprite2D
		var expected_path: String = "res://assets/jellycats/%s/stages/stage_%d.png" % [species_id, int(expected_state.get("stage", 0))]
		_expect(sprite != null and sprite.texture != null and sprite.texture.resource_path == expected_path, "Reloaded %s renders its saved stage image" % pet_id)
		actor.free()
	GameState.reset_to_default()


func _write_text(path: String, contents: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(contents)
	file.flush()
	var status: Error = file.get_error()
	file.close()
	return status == OK


func _read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var contents: String = file.get_as_text()
	file.close()
	return contents


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("RUNTIME_ACCEPTANCE_OK checks=%d" % checks)
		get_tree().quit(0)
		return
	for failure in failures:
		push_error("RUNTIME_ACCEPTANCE_FAIL: %s" % failure)
	print("RUNTIME_ACCEPTANCE_FAILED checks=%d failures=%d" % [checks, failures.size()])
	get_tree().quit(1)
