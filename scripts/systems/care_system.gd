extends Node
class_name CareSystem


static func feed_food(pet_id: String, consume_item: bool = true) -> bool:
	return _consume_food_for_pet(pet_id, "food_basic", consume_item)


static func feed_cookie(pet_id: String, consume_item: bool = true) -> bool:
	return _consume_food_for_pet(pet_id, "cookie_basic", consume_item)


static func touch_pet(pet_id: String, injected_now_seconds: float = -1.0) -> bool:
	var pet: Dictionary = GameState.get_pet(pet_id)
	if pet.is_empty():
		RuntimeLogger.log_error("No pet found for id: %s" % pet_id)
		return false
	var care_stats: Dictionary = GameState.get_current_care_stats(pet_id)
	var now_seconds: float = Time.get_unix_time_from_system() if injected_now_seconds < 0.0 else injected_now_seconds
	var cooldown: float = maxf(float(GameApp.get_balance_value("touch_cooldown_seconds")), 0.0)
	var last_touch: float = float(care_stats.get("last_touch_effect_at", 0.0))
	if now_seconds - last_touch < cooldown:
		RuntimeLogger.log_info_throttled("touch_cooldown_%s" % pet_id, "Touch ignored: cooldown")
		return false
	var reset_seconds: float = maxf(float(GameApp.get_balance_value("touch_exp_reset_seconds")), 1.0)
	var window_started_at: float = float(care_stats.get("touch_exp_hour_started_at", 0.0))
	if window_started_at <= 0.0 or now_seconds < window_started_at or now_seconds - window_started_at >= reset_seconds:
		window_started_at = now_seconds
		care_stats["touch_exp_hour_started_at"] = window_started_at
		care_stats["touch_exp_hour_id"] = str(window_started_at)
		care_stats["touch_growth_exp_hour"] = 0
		care_stats["touch_cap_notified_hour_id"] = ""
	var window_id: String = str(window_started_at)
	var old_mood: int = int(pet.get("mood", 0))
	var old_exp: int = int(pet.get("growth_exp", 0))
	pet["mood"] = _clamp_stat(old_mood + int(GameApp.get_balance_value("touch_mood_add")), "max_mood")
	var cap: int = max(int(GameApp.get_balance_value("touch_growth_exp_cap")), 0)
	var exp_this_hour: int = max(int(care_stats.get("touch_growth_exp_hour", 0)), 0)
	var reached_cap_now: bool = false
	if exp_this_hour < cap:
		var exp_add: int = min(int(GameApp.get_balance_value("touch_growth_exp_add")), cap - exp_this_hour)
		pet["growth_exp"] = old_exp + exp_add
		care_stats["touch_growth_exp_hour"] = exp_this_hour + exp_add
		reached_cap_now = int(care_stats["touch_growth_exp_hour"]) >= cap
	if old_mood == int(pet.get("mood", 0)) and old_exp == int(pet.get("growth_exp", 0)):
		GameState.set_pet_and_care_stats(pet_id, pet, care_stats)
		return false
	care_stats["last_touch_effect_at"] = now_seconds
	pet["last_touched_at"] = Time.get_datetime_string_from_system()
	if not GameState.set_pet_and_care_stats(pet_id, pet, care_stats):
		return false
	RuntimeLogger.log_action("%s touch" % pet_id)
	if old_mood != int(pet.get("mood", 0)):
		RuntimeLogger.log_state("%s mood: %d -> %d" % [pet_id, old_mood, int(pet.get("mood", 0))])
	if old_exp != int(pet.get("growth_exp", 0)):
		RuntimeLogger.log_state("%s growth_exp: %d -> %d" % [pet_id, old_exp, int(pet.get("growth_exp", 0))])
	if reached_cap_now and str(care_stats.get("touch_cap_notified_hour_id", "")) != window_id:
		care_stats["touch_cap_notified_hour_id"] = window_id
		GameState.set_pet_and_care_stats(pet_id, pet, care_stats)
		RuntimeLogger.log_info_throttled("touch_growth_cap_%s" % pet_id, "Touch growth cap reached for %s: %d/%d this hour" % [pet_id, int(care_stats["touch_growth_exp_hour"]), cap])
	return true


static func clean_tank() -> bool:
	var aquarium: Dictionary = GameState.get_aquarium()
	var old_cleanliness: int = int(aquarium.get("cleanliness", 0))
	var target_cleanliness: int = int(GameApp.get_balance_value("cleanliness_after_clean"))
	if old_cleanliness >= target_cleanliness:
		RuntimeLogger.log_info("Tank is already clean")
		return false
	GameState.set_aquarium_cleanliness(target_cleanliness)
	RuntimeLogger.log_state("Tank cleanliness: %d -> %d" % [old_cleanliness, target_cleanliness])
	return true


static func give_medicine(pet_id: String) -> bool:
	var pet: Dictionary = GameState.get_pet(pet_id)
	if pet.is_empty():
		RuntimeLogger.log_error("No pet found for id: %s" % pet_id)
		return false
	var old_count: int = GameState.get_inventory_count("medicine_basic")
	var old_health: String = str(pet.get("health", "healthy"))
	if old_count <= 0 or old_health == "healthy":
		return false
	GameState.set_inventory_count("medicine_basic", old_count - 1)
	pet["health"] = "healthy"
	pet["last_medicine_at"] = Time.get_datetime_string_from_system()
	GameState.set_pet(pet_id, pet)
	RuntimeLogger.log_state("health: %s -> healthy" % old_health)
	return true


static func simulate_days(days: float) -> void:
	apply_offline_care_decay(int(round(maxf(days, 0.0) * TimeManager.SECONDS_PER_DAY)))


static func apply_online_care_decay(elapsed_seconds: int) -> void:
	var seconds_per_minute: int = max(int(GameApp.get_balance_value("seconds_per_minute")), 1)
	var minutes: int = int(floor(float(max(elapsed_seconds, 0)) / float(seconds_per_minute)))
	if minutes <= 0:
		return
	var hunger_decay: int = max(int(GameApp.get_balance_value("hunger_decay_per_minute")), 0)
	var hungry_max: int = max(int(GameApp.get_balance_value("hungry_hunger_max")), 0)
	var hungry_mood_decay: int = max(int(GameApp.get_balance_value("mood_decay_hungry_per_min")), 0)
	var starving_mood_decay: int = max(int(GameApp.get_balance_value("mood_decay_starving_per_min")), 0)
	for pet_id in GameState.get_pet_ids():
		var pet: Dictionary = GameState.get_pet(pet_id)
		var old_hunger: int = int(pet.get("hunger", 0))
		var old_mood: int = int(pet.get("mood", 0))
		var hunger: int = old_hunger
		var mood: int = old_mood
		for _minute in range(minutes):
			if hunger <= 0:
				mood = maxi(0, mood - starving_mood_decay)
			else:
				if hunger <= hungry_max:
					mood = maxi(0, mood - hungry_mood_decay)
				hunger = maxi(0, hunger - hunger_decay)
		pet["hunger"] = hunger
		pet["mood"] = mood
		if not GameState.set_pet(pet_id, pet):
			continue
		_log_pet_int_change(pet_id, "hunger", old_hunger, hunger)
		_log_pet_int_change(pet_id, "mood", old_mood, mood)
		if old_hunger > hungry_max and hunger <= hungry_max:
			RuntimeLogger.log_info("hungry %s" % pet_id)


static func apply_offline_care_decay(elapsed_seconds: int) -> void:
	var days: float = TimeManager.days_from_seconds(float(max(elapsed_seconds, 0)))
	if days <= 0.0:
		return
	var max_hunger: int = int(GameApp.get_balance_value("max_hunger"))
	var max_mood: int = int(GameApp.get_balance_value("max_mood"))
	var hunger_floor: int = clampi(int(GameApp.get_balance_value("offline_hunger_floor")), 0, max_hunger)
	var mood_floor: int = clampi(int(GameApp.get_balance_value("offline_mood_floor")), 0, max_mood)
	for pet_id in GameState.get_pet_ids():
		var pet: Dictionary = GameState.get_pet(pet_id)
		var species: Dictionary = _get_table_entry("species", str(pet.get("species_id", "normal_jellycat")))
		var old_hunger: int = int(pet.get("hunger", 0))
		var old_mood: int = int(pet.get("mood", 0))
		var old_health: String = str(pet.get("health", "healthy"))
		var raw_hunger: int = old_hunger - int(round(float(species.get("hunger_decay_per_day", 0)) * days))
		var raw_mood: int = old_mood - int(round(float(species.get("mood_decay_per_day", 0)) * days))
		pet["hunger"] = clampi(max(raw_hunger, hunger_floor), hunger_floor, max_hunger)
		pet["mood"] = clampi(max(raw_mood, mood_floor), mood_floor, max_mood)
		GameState.set_pet(pet_id, pet)
		_log_pet_int_change(pet_id, "hunger", old_hunger, int(pet.get("hunger", 0)))
		_log_pet_int_change(pet_id, "mood", old_mood, int(pet.get("mood", 0)))
		if raw_hunger < hunger_floor or raw_mood < mood_floor:
			RuntimeLogger.log_info("offline floor applied %s hunger %d -> %d mood %d -> %d" % [pet_id, old_hunger, int(pet.get("hunger", 0)), old_mood, int(pet.get("mood", 0))])
		_log_string_change("%s health" % pet_id, old_health, str(pet.get("health", "healthy")))
	var aquarium: Dictionary = GameState.get_aquarium()
	var cleanliness_decay: float = 0.0
	var pet_ids: Array[String] = GameState.get_pet_ids()
	if not pet_ids.is_empty():
		var first_species: Dictionary = _get_table_entry("species", str(GameState.get_pet(pet_ids[0]).get("species_id", "normal_jellycat")))
		cleanliness_decay = float(first_species.get("cleanliness_decay_per_day", 0))
	var max_cleanliness: int = int(GameApp.get_balance_value("max_cleanliness"))
	var old_cleanliness: int = int(aquarium.get("cleanliness", max_cleanliness))
	var next_cleanliness: int = clampi(old_cleanliness - int(round(cleanliness_decay * days)), 0, max_cleanliness)
	GameState.set_aquarium_cleanliness(next_cleanliness)
	_log_int_change("tank cleanliness", old_cleanliness, next_cleanliness)
	if next_cleanliness <= 0:
		for pet_id in pet_ids:
			var pet: Dictionary = GameState.get_pet(pet_id)
			if str(pet.get("health", "healthy")) == "healthy":
				pet["health"] = "sick"
				if GameState.set_pet(pet_id, pet):
					RuntimeLogger.log_state("%s health healthy -> sick: tank cleanliness reached 0" % pet_id)


static func build_fed_pet_data(pet_id: String, item_id: String) -> Dictionary:
	var item: Dictionary = _get_table_entry("items", item_id)
	var pet: Dictionary = GameState.get_pet(pet_id)
	if item.is_empty() or pet.is_empty():
		RuntimeLogger.log_error("Invalid food target: %s" % pet_id)
		return {}
	var old_hunger: int = int(pet.get("hunger", 0))
	var old_mood: int = int(pet.get("mood", 0))
	var old_exp: int = int(pet.get("growth_exp", 0))
	if item_id == "food_basic" and old_hunger > int(GameApp.get_balance_value("food_refusal_hunger_threshold")):
		return {}
	var max_hunger: int = int(GameApp.get_balance_value("max_hunger"))
	var max_mood: int = int(GameApp.get_balance_value("max_mood"))
	if old_hunger >= max_hunger and old_mood >= max_mood and int(item.get("growth_exp_add", 0)) <= 0:
		return {}
	pet["hunger"] = _clamp_stat(old_hunger + int(item.get("hunger_add", 0)), "max_hunger")
	pet["mood"] = _clamp_stat(old_mood + int(item.get("mood_add", 0)), "max_mood")
	pet["growth_exp"] = old_exp + int(item.get("growth_exp_add", 0))
	pet["last_fed_at"] = Time.get_datetime_string_from_system()
	return pet


static func _consume_food_for_pet(pet_id: String, item_id: String, consume_item: bool) -> bool:
	var old_pet: Dictionary = GameState.get_pet(pet_id)
	var next_pet: Dictionary = build_fed_pet_data(pet_id, item_id)
	if next_pet.is_empty():
		return false
	var consumes_inventory: bool = consume_item and item_id != "food_basic"
	if consumes_inventory and not InventorySystem.spend_item(item_id, 1):
		return false
	if not GameState.set_pet(pet_id, next_pet):
		if consumes_inventory:
			InventorySystem.add_item(item_id, 1)
		return false
	_log_pet_int_change(pet_id, "hunger", int(old_pet.get("hunger", 0)), int(next_pet.get("hunger", 0)))
	_log_pet_int_change(pet_id, "mood", int(old_pet.get("mood", 0)), int(next_pet.get("mood", 0)))
	_log_pet_int_change(pet_id, "growth_exp", int(old_pet.get("growth_exp", 0)), int(next_pet.get("growth_exp", 0)))
	return true


static func is_food_refused(pet: Dictionary) -> bool:
	return int(pet.get("hunger", int(GameApp.get_balance_value("max_hunger")))) > int(GameApp.get_balance_value("food_refusal_hunger_threshold"))


static func _get_table_entry(table_name: String, key: String) -> Dictionary:
	var entry: Variant = GameApp.get_table(table_name).get(key, {})
	return entry as Dictionary if entry is Dictionary else {}


static func _clamp_stat(value: int, max_key: String) -> int:
	var maximum: int = int(GameApp.get_balance_value(max_key))
	return clampi(value, 0, maximum)


static func _log_int_change(label: String, old_value: int, new_value: int) -> void:
	if old_value != new_value:
		RuntimeLogger.log_state("%s: %d -> %d" % [label, old_value, new_value])


static func _log_pet_int_change(pet_id: String, label: String, old_value: int, new_value: int) -> void:
	if old_value != new_value:
		RuntimeLogger.log_state("%s %s %d -> %d" % [pet_id, label, old_value, new_value])


static func _log_string_change(label: String, old_value: String, new_value: String) -> void:
	if old_value != new_value:
		RuntimeLogger.log_state("%s: %s -> %s" % [label, old_value, new_value])
