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
	_expect(GameState.get_inventory_count("food_basic") == 5, "New game starts with five food tokens")
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
	var pet_b: Dictionary = GameState.get_pet(pet_b_id)
	var pet_b_before: Dictionary = pet_b.duplicate(true)
	var food_before: int = GameState.get_inventory_count("food_basic")
	_expect(CareSystem.feed_food(pet_a_id), "Food feeds the explicitly selected pet")
	_expect(GameState.get_inventory_count("food_basic") == food_before - 1, "One successful feed spends one shared food token")
	_expect(int(GameState.get_pet(pet_a_id).get("hunger", 0)) > int(pet_a.get("hunger", 0)), "Food raises the target pet's hunger stat")
	_expect(int(GameState.get_pet(pet_b_id).get("hunger", 0)) == int(pet_b_before.get("hunger", -1)), "Food does not change another pet's stats")
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
	var initial_stats: Dictionary = {
		"touch_growth_exp_today": 0,
		"touch_exp_date": str(Time.get_unix_time_from_system()),
		"last_touch_effect_at": 0.0,
		"touch_cap_notified_date": ""
	}
	GameState.set_pet_and_care_stats(pet_id, pet, initial_stats)
	_expect(CareSystem.touch_pet(pet_id), "First touch succeeds for explicit pet ID")
	var exp_after_first: int = int(GameState.get_pet(pet_id).get("growth_exp", -1))
	_expect(not CareSystem.touch_pet(pet_id), "Immediate touch is blocked by cooldown")
	_expect(int(GameState.get_pet(pet_id).get("growth_exp", -1)) == exp_after_first, "Cooldown touch adds no EXP")
	for _touch in range(19):
		var pet_after_touch: Dictionary = GameState.get_pet(pet_id)
		var stats: Dictionary = GameState.get_current_care_stats(pet_id)
		stats["last_touch_effect_at"] = 0.0
		GameState.set_pet_and_care_stats(pet_id, pet_after_touch, stats)
		CareSystem.touch_pet(pet_id)
	var after_cap: Dictionary = GameState.get_current_care_stats(pet_id)
	_expect(int(after_cap.get("touch_growth_exp_today", -1)) == 20, "Touch grants exactly 20 EXP per window")
	var capped_pet: Dictionary = GameState.get_pet(pet_id)
	var capped_exp: int = int(capped_pet.get("growth_exp", -1))
	after_cap["last_touch_effect_at"] = 0.0
	GameState.set_pet_and_care_stats(pet_id, capped_pet, after_cap)
	_expect(not CareSystem.touch_pet(pet_id), "Touch after 20/20 is a no-op")
	_expect(int(GameState.get_pet(pet_id).get("growth_exp", -1)) == capped_exp, "Touch after cap adds no EXP")
	var expired_pet: Dictionary = GameState.get_pet(pet_id)
	var expired_stats: Dictionary = GameState.get_current_care_stats(pet_id)
	expired_stats["touch_exp_date"] = str(Time.get_unix_time_from_system() - 601.0)
	expired_stats["last_touch_effect_at"] = 0.0
	GameState.set_pet_and_care_stats(pet_id, expired_pet, expired_stats)
	_expect(CareSystem.touch_pet(pet_id), "Touch succeeds after the ten-minute window expires")
	_expect(int(GameState.get_current_care_stats(pet_id).get("touch_growth_exp_today", -1)) == 1, "Expired touch window resets the counter")
	var other_id: String = GameState.get_pet_ids()[1]
	_expect(int(GameState.get_current_care_stats(other_id).get("touch_growth_exp_today", -1)) == 0, "Touch cap is saved independently for each pet")
	var before_food_exp: int = int(GameState.get_pet(pet_id).get("growth_exp", 0))
	_expect(CareSystem.feed_food(pet_id), "Food still works after the touch cap")
	_expect(int(GameState.get_pet(pet_id).get("growth_exp", 0)) > before_food_exp, "Food grants growth EXP after the touch cap")
	var before_cookie_exp: int = int(GameState.get_pet(pet_id).get("growth_exp", 0))
	_expect(CareSystem.feed_cookie(pet_id), "Cookie still works after the touch cap")
	_expect(int(GameState.get_pet(pet_id).get("growth_exp", 0)) > before_cookie_exp, "Cookie grants growth EXP after the touch cap")


func _check_evolution_and_economy() -> void:
	var pet_id: String = GameState.get_pet_ids()[0]
	var pet: Dictionary = GameState.get_pet(pet_id)
	pet["stage"] = 1
	pet["growth_exp"] = 900
	GameState.set_pet(pet_id, pet)
	GameState.set_currency("bubble_coin", 0)
	for expected_stage in range(2, 6):
		_expect(EvolutionSystem.can_evolve(pet_id), "%s can evolve to Stage %d" % [pet_id, expected_stage])
		_expect(EvolutionSystem.evolve(pet_id), "Evolution reaches Stage %d" % expected_stage)
		_expect(int(GameState.get_pet(pet_id).get("stage", 0)) == expected_stage, "Stage is %d" % expected_stage)
		var durable_save: Variant = JSON.parse_string(_read_text(SaveManager.get_save_path()))
		var durable_pets: Dictionary = (durable_save as Dictionary).get("pets", {}) if durable_save is Dictionary else {}
		var durable_pet: Dictionary = durable_pets.get(pet_id, {})
		_expect(int(durable_pet.get("stage", 0)) == expected_stage, "Evolution persists stage %d immediately" % expected_stage)
		var durable_currency: Dictionary = (durable_save as Dictionary).get("currency", {}) if durable_save is Dictionary else {}
		_expect(int(durable_currency.get("bubble_coin", -1)) == GameState.get_currency("bubble_coin"), "Evolution persists its shared coin bonus immediately")
	_expect(EvolutionSystem.get_next_stage_data(pet_id).is_empty(), "Stage 5 has no next-stage data")
	_expect(not EvolutionSystem.evolve(pet_id), "Stage 5 evolve is safely rejected")
	_expect(not EvolutionSystem.evolve("missing_pet"), "Evolution rejects unknown pet IDs")
	_expect(int(GameState.get_pet(pet_id).get("stage", 0)) == 5, "Stage never exceeds 5")
	GameState.set_currency("bubble_coin", 100)
	var old_food: int = GameState.get_inventory_count("food_basic")
	_expect(ShopSystem.buy_item("food_basic"), "Shop buys food")
	_expect(GameState.get_currency("bubble_coin") == 95, "Food purchase costs five coins")
	_expect(GameState.get_inventory_count("food_basic") == old_food + 1, "Food purchase adds shared inventory")
	_expect(ShopSystem.buy_item("cookie_basic"), "Shop buys cookies")
	_expect(GameState.get_currency("bubble_coin") == 87, "Cookie purchase costs eight coins")
	_expect(ShopSystem.buy_item("medicine_basic"), "Shop buys medicine")
	_expect(GameState.get_currency("bubble_coin") == 67, "Medicine purchase costs twenty coins")
	GameState.set_currency("bubble_coin", 0)
	var medicine_before: int = GameState.get_inventory_count("medicine_basic")
	_expect(not ShopSystem.buy_item("medicine_basic"), "Insufficient coin purchase fails")
	_expect(GameState.get_currency("bubble_coin") == 0, "Currency never falls below zero")
	_expect(GameState.get_inventory_count("medicine_basic") == medicine_before, "Failed purchase changes no inventory")
	_expect(CurrencySystem.calculate_offline_income(60) == 6, "Shared offline income counts three eligible aquarium pets")
	var second_pet: Dictionary = GameState.get_pet(GameState.get_pet_ids()[1])
	second_pet["mood"] = 0
	GameState.set_pet(str(second_pet.get("pet_id", "")), second_pet)
	_expect(CurrencySystem.calculate_offline_income(60) == 4, "Offline income excludes a pet below the shared mood threshold")


func _check_json_round_trip_and_save_load() -> void:
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
