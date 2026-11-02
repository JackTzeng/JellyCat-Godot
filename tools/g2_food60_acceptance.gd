extends Node

const ISOLATED_SAVE_PATH: String = "user://g2_food60_acceptance_save.json"
var checks: int = 0
var failures: int = 0

func _ready() -> void:
	print("G2 food60: start")
	var watchdog := get_tree().create_timer(300.0, true, false, true)
	watchdog.timeout.connect(_on_watchdog)
	call_deferred("_run")

func _on_watchdog() -> void:
	print("WATCHDOG_TIMEOUT")
	get_tree().quit(2)

func _run() -> void:
	print("G2 food60: reset and hatch three-pet fixture")
	CoinDropSystem.force_roll(1.0)
	CareSystem.reset_online_hunger_carry()
	TimeManager.set_time_scale(1)
	SaveManager.set_save_path_for_test(ISOLATED_SAVE_PATH)
	SaveManager.reset_save()
	GameApp.load_data_tables()
	GameState.reset_to_default()
	EggSystem.ensure_starter_eggs()
	for egg in GameState.get_nursery_eggs():
		for _tap in range(int(egg.get("required_clicks", 10))):
			HatchSystem.tap_egg(str(egg.get("egg_id", "")))
	var pet_ids: Array[String] = GameState.get_active_pet_ids()
	_check(pet_ids.size() == 3, "fixture has three hatched active pets")
	for pet_id in pet_ids:
		var pet: Dictionary = GameState.get_pet(pet_id)
		pet["hunger"] = 20
		GameState.set_pet(pet_id, pet)
	var aquarium_scene := load("res://scenes/aquarium/aquarium.tscn") as PackedScene
	var aquarium := aquarium_scene.instantiate() as Control
	get_tree().root.add_child(aquarium)
	await get_tree().process_frame
	TimeManager.set_time_scale(60)
	print("G2 food60: x60 active; start three waves")
	var tokens: Array[String] = []
	var drops: Dictionary = {}
	var real_start := Time.get_ticks_msec()
	print("G2 food60: water_rect=%s" % str(aquarium.get("active_water_rect")))
	for wave in range(3):
		print("G2 food60: wave %d feed" % (wave + 1))
		for pet_index in range(pet_ids.size()):
			var pet_id: String = pet_ids[pet_index]
			var water: Rect2 = aquarium.get("active_water_rect")
			var position := Vector2(water.position.x + water.size.x * (0.2 + pet_index * 0.3), water.position.y + water.size.y * 0.25)
			var now := Time.get_unix_time_from_system()
			var drop: Dictionary = FoodDropSystem.drop_food(position)
			var token: String = str(drop.get("token_id", ""))
			if not token.is_empty():
				tokens.append(token)
				drops[token] = {"pet": pet_id, "drop": drop, "placed": now}
			if tokens.size() == 1:
				var before := float(drop.get("expires_at", 0.0))
				TimeManager.set_time_scale(1)
				TimeManager.set_time_scale(60)
				var unchanged := false
				for current in GameState.get_food_drops():
					if str(current.get("token_id", "")) == token:
						unchanged = absf(float(current.get("expires_at", 0.0)) - before) <= 0.25
				_check(unchanged, "deadline preserved across x1 then x60")
		var wave_start := Time.get_ticks_msec()
		while Time.get_ticks_msec() - wave_start < 60000:
			await get_tree().process_frame
			var remaining := 0
			for token in tokens:
				if GameState.get_food_drops().any(func(d): return str(d.get("token_id", "")) == token):
					remaining += 1
			if remaining == 0:
				break
		print("G2 food60: wave %d settled; elapsed_real=%.3f" % [wave + 1, float(Time.get_ticks_msec() - wave_start) / 1000.0])
	print("G2 food60: validate ledger and meal logs")
	var logs := RuntimeLogger.get_logs()
	var meal_tokens_by_pet: Dictionary = {}
	var expired_tokens: Dictionary = {}
	for entry in logs:
		var text := str(entry)
		if text.contains("food expired/cleared"):
			for token in tokens:
				if text.contains(token): expired_tokens[token] = true
		for token in tokens:
			if text.contains("from meal " + token) and text.contains(" by "):
				for pet_id in pet_ids:
					if text.contains(" by " + pet_id):
						if not meal_tokens_by_pet.has(pet_id): meal_tokens_by_pet[pet_id] = {}
						meal_tokens_by_pet[pet_id][token] = true
	var counts: Dictionary = {}
	for pet_id in pet_ids:
		counts[pet_id] = 0
		for token in meal_tokens_by_pet.get(pet_id, {}).keys(): counts[pet_id] += 1
		print("G2 food60: pet=%s meals=%d" % [pet_id, counts[pet_id]])
	_check(tokens.size() == 9, "nine drops were created")
	_check(GameState.get_food_drops().is_empty(), "food_drops ledger is empty")
	_check((aquarium.get("food_claims") as Dictionary).is_empty(), "claims are empty")
	_check(expired_tokens.is_empty(), "no food expired/cleared log for any of the nine tokens")
	var all_meals := true
	for pet_id in pet_ids: all_meals = all_meals and int(counts[pet_id]) == 3
	_check(all_meals, "each pet settled exactly three meals by unique food token")
	for token in tokens:
		var row: Dictionary = drops[token]
		var life := float(row["drop"].get("expires_at", 0.0)) - float(row["placed"])
		print("G2 food60: token=%s life_real=%.3f" % [token, life])
		_check(life >= 44.5, "food token %s lifetime >= 44.5 real seconds" % token)
	print("G2 food60: elapsed_total_real=%.3f" % (float(Time.get_ticks_msec() - real_start) / 1000.0))
	TimeManager.set_time_scale(1)
	aquarium.queue_free()
	if failures == 0:
		print("G2_FOOD60_ACCEPTANCE_OK checks=%d" % checks)
		get_tree().quit(0)
	else:
		print("G2_FOOD60_ACCEPTANCE_FAILED checks=%d failures=%d" % [checks, failures])
		get_tree().quit(1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures += 1
	print("G2 food60: %s %s" % ["PASS" if condition else "FAIL", label])
