extends Node

const SAVE_PATH: String = "user://g2_partner_egg_acceptance_save.json"
var checks: int = 0
var failures: int = 0

func _ready() -> void:
	print("G2 partner egg: start")
	var watchdog := get_tree().create_timer(300.0, true, false, true)
	watchdog.timeout.connect(_on_watchdog)
	call_deferred("_run")

func _on_watchdog() -> void:
	print("WATCHDOG_TIMEOUT")
	get_tree().quit(2)

func _run() -> void:
	SaveManager.set_save_path_for_test(SAVE_PATH)
	SaveManager.reset_save()
	GameApp.load_data_tables()
	GameState.reset_to_default()
	EggSystem.ensure_starter_eggs()
	for egg in GameState.get_nursery_eggs():
		for _tap in range(int(egg.get("required_clicks", 10))):
			HatchSystem.tap_egg(str(egg.get("egg_id", "")))
	_check(GameState.get_pet_ids().size() == 3, "starter fixture has three pets")
	var expected: Array[int] = [100, 150, 225, 340, 510, 760, 1140, 1710]
	for index in range(expected.size()):
		var fixture: Dictionary = GameState.to_save_dict()
		var pets: Dictionary = fixture["pets"]
		while pets.size() < index + 3:
			var id: String = "test_%03d" % pets.size()
			pets[id] = {"pet_id": id, "species_id": "normal_jellycat", "personality_id": "curious"}
		var nursery: Dictionary = fixture["nursery"]
		nursery["eggs"] = []
		fixture["nursery"] = nursery
		fixture["pets"] = pets
		GameState.set_data(fixture)
		_check(ShopSystem.get_item_price("partner_egg_jellycat") == expected[index], "price n=%d is %d" % [index + 3, expected[index]])
	GameState.reset_to_default()
	EggSystem.ensure_starter_eggs()
	for egg in GameState.get_nursery_eggs():
		for _tap in range(int(egg.get("required_clicks", 10))):
			HatchSystem.tap_egg(str(egg.get("egg_id", "")))
	GameState.set_currency("bubble_coin", 99)
	_check(not ShopSystem.can_buy("partner_egg_jellycat"), "insufficient funds prevents purchase")
	_check(not ShopSystem.buy_item("partner_egg_jellycat"), "insufficient funds purchase rejected")
	_check(GameState.get_nursery_eggs().is_empty(), "failed purchase adds no egg")
	GameState.set_currency("bubble_coin", 250)
	var before_eggs: int = GameState.get_nursery_eggs().size()
	var before_coins: int = GameState.get_currency("bubble_coin")
	_check(ShopSystem.buy_item("partner_egg_jellycat"), "affordable purchase succeeds")
	_check(not ShopSystem.buy_item("partner_egg_jellycat"), "second purchase rejected at updated price/funds")
	_check(GameState.get_nursery_eggs().size() == before_eggs + 1, "single purchase adds exactly one nursery egg")
	_check(GameState.get_currency("bubble_coin") == before_coins - 100, "purchase deducts exact price")
	_check(SaveManager.save_game(), "purchased egg save succeeds")
	GameState.reset_to_default()
	_check(SaveManager.load_game(), "restart reload succeeds")
	_check(GameState.get_nursery_eggs().size() == 1 and GameState.get_currency("bubble_coin") == before_coins - 100, "unhatched egg and deduction persist")
	var egg: Dictionary = GameState.get_nursery_eggs()[0]
	for _tap in range(int(egg.get("required_clicks", 10))):
		HatchSystem.tap_egg(str(egg.get("egg_id", "")))
	var hatched: Dictionary = {}
	if GameState.get_pet_ids().size() > 3:
		hatched = GameState.get_pet(GameState.get_pet_ids()[-1])
	_check(GameState.get_pet_ids().size() == 4, "egg hatches into fourth pet")
	_check(int(hatched.get("hunger", -1)) == 40 and int(hatched.get("mood", -1)) == 70, "hatched pet starts at hunger 40 mood 70")
	var full_fixture: Dictionary = GameState.to_save_dict()
	var all_pets: Dictionary = full_fixture["pets"]
	while all_pets.size() < GameState.get_max_pets_technical():
		var id: String = "full_%03d" % all_pets.size()
		all_pets[id] = {"pet_id": id, "species_id": "normal_jellycat", "personality_id": "curious"}
	full_fixture["pets"] = all_pets
	GameState.set_data(full_fixture)
	_check(not ShopSystem.can_buy("partner_egg_jellycat"), "technical pet cap disables purchase")
	_check(not ShopSystem.buy_item("partner_egg_jellycat"), "technical pet cap rejects purchase")
	print("G2 partner egg: B6 deterministic three-wave x60 live production flow")
	RuntimeLogger.clear()
	CoinDropSystem.force_roll(1.0)
	GameState.reset_to_default()
	EggSystem.ensure_starter_eggs()
	for starter in GameState.get_nursery_eggs():
		for _tap in range(int(starter.get("required_clicks", 10))):
			HatchSystem.tap_egg(str(starter.get("egg_id", "")))
	var pet_ids: Array[String] = GameState.get_active_pet_ids()
	for pet_id in pet_ids:
		var pet: Dictionary = GameState.get_pet(pet_id)
		pet["hunger"] = 20
		GameState.set_pet(pet_id, pet)
	var aquarium: Control = (load("res://scenes/aquarium/aquarium.tscn") as PackedScene).instantiate() as Control
	get_tree().root.add_child(aquarium)
	await get_tree().process_frame
	TimeManager.set_time_scale(60)
	var flow_start: int = Time.get_ticks_msec()
	var waves: int = 0
	var bought_egg: bool = false
	for wave in range(3):
		waves += 1
		var wave_start: int = Time.get_ticks_msec()
		var eaten_this_round: int = 0
		for pet_index in range(pet_ids.size()):
			for meal_index in range(3):
				if pet_index > 0 or meal_index > 0:
					CareSystem.apply_online_care_decay(1200)
				var water: Rect2 = aquarium.get("active_water_rect")
				var position := Vector2(water.position.x + water.size.x * (0.2 + pet_index * 0.3), water.position.y + water.size.y * 0.25)
				aquarium.call("_drop_basic_food", position, pet_ids[pet_index])
				var token_id: String = ""
				var current_food: Array = GameState.get_food_drops()
				if not current_food.is_empty():
					token_id = str(current_food[-1].get("token_id", ""))
				var food_wait_start: int = Time.get_ticks_msec()
				while Time.get_ticks_msec() - food_wait_start < 60000 and not GameState.get_food_drops().is_empty():
					await get_tree().process_frame
				if not GameState.get_food_drops().is_empty():
					break
				for entry in RuntimeLogger.get_logs():
					if str(entry).contains("food eaten %s " % token_id):
						eaten_this_round += 1
						break
				for drop in GameState.get_coin_drops():
					aquarium.call("_on_coin_bubble_collected", str(drop.get("token_id", "")), int(drop.get("value", 0)), false, str(drop.get("source_pet_id", "")))
		print("G2 partner egg: round=%d fed=%d eaten=%d coins=%d elapsed_real=%.2f" % [waves, pet_ids.size() * 3, eaten_this_round, GameState.get_currency("bubble_coin"), float(Time.get_ticks_msec() - wave_start) / 1000.0])
		if GameState.get_currency("bubble_coin") >= ShopSystem.get_item_price("partner_egg_jellycat") and ShopSystem.buy_item("partner_egg_jellycat"):
			bought_egg = true
			break
		if eaten_this_round < pet_ids.size() * 3:
			break
	_check(bought_egg and waves <= 3, "at most three live feeding waves earned enough and bought a partner egg")
	if bought_egg:
		var earned_egg: Dictionary = GameState.get_nursery_eggs()[-1]
		for _tap in range(int(earned_egg.get("required_clicks", 10))):
			HatchSystem.tap_egg(str(earned_egg.get("egg_id", "")))
		var earned_pet: Dictionary = {}
		if GameState.get_pet_ids().size() > 3:
			earned_pet = GameState.get_pet(GameState.get_pet_ids()[-1])
		_check(GameState.get_pet_ids().size() == 4, "B6 purchased egg hatches into fourth pet")
		_check(int(earned_pet.get("hunger", -1)) == 40 and int(earned_pet.get("mood", -1)) == 70, "B6 hatched pet starts at hunger 40 mood 70")
	TimeManager.set_time_scale(1)
	aquarium.queue_free()
	TimeManager.set_time_scale(1)
	if failures == 0:
		print("G2_PARTNER_EGG_ACCEPTANCE_OK checks=%d" % checks)
		get_tree().quit(0)
	else:
		print("G2_PARTNER_EGG_ACCEPTANCE_FAILED checks=%d failures=%d" % [checks, failures])
		get_tree().quit(1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("G2 partner egg: %s %s" % ["PASS" if condition else "FAIL", label])