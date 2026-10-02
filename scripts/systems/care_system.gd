extends Node
class_name CareSystem


static func feed_food(pet_id: String, consume_item: bool = true) -> bool:
	return _consume_food_for_pet(pet_id, "food_basic", consume_item)


static func feed_cookie(pet_id: String, consume_item: bool = true) -> bool:
	return _consume_food_for_pet(pet_id, "cookie_basic", consume_item)


static func touch_pet(pet_id: String) -> bool:
	var pet: Dictionary = GameState.get_pet(pet_id)
	if pet.is_empty():
		RuntimeLogger.log_error("No pet found for id: %s" % pet_id)
		return false
	var care_stats: Dictionary = GameState.get_current_care_stats(pet_id)
	var now_seconds: float = Time.get_unix_time_from_system()
	var cooldown: float = max(float(GameApp.get_balance_value("touch_cooldown_seconds", 0.5)), 0.0)
	var last_touch: float = float(care_stats.get("last_touch_effect_at", 0.0))
	if now_seconds - last_touch < cooldown:
		RuntimeLogger.log_info_throttled("touch_cooldown_%s" % pet_id, "Touch ignored: cooldown")
		return false
	var reset_seconds: float = max(float(GameApp.get_balance_value("touch_exp_reset_seconds", 600)), 1.0)
	var window_started_at: float = _saved_touch_window_start(care_stats)
	var window_id: String = str(window_started_at)
	if window_started_at <= 0.0 or now_seconds - window_started_at >= reset_seconds:
		window_started_at = now_seconds
		window_id = str(window_started_at)
		care_stats["touch_growth_exp_today"] = 0
		care_stats["touch_exp_date"] = window_id
		care_stats["touch_cap_notified_date"] = ""
	var old_mood: int = int(pet.get("mood", 0))
	var old_exp: int = int(pet.get("growth_exp", 0))
	pet["mood"] = _clamp_stat(old_mood + int(GameApp.get_balance_value("touch_mood_add", 5)), "max_mood")
	var cap: int = max(int(GameApp.get_balance_value("touch_growth_exp_cap", 20)), 0)
	var exp_today: int = max(int(care_stats.get("touch_growth_exp_today", 0)), 0)
	var reached_cap_now: bool = false
	if exp_today < cap:
		var exp_add: int = min(int(GameApp.get_balance_value("touch_growth_exp_add", 1)), cap - exp_today)
		pet["growth_exp"] = old_exp + exp_add
		care_stats["touch_growth_exp_today"] = exp_today + exp_add
		reached_cap_now = int(care_stats["touch_growth_exp_today"]) >= cap
	if old_mood == int(pet.get("mood", 0)) and old_exp == int(pet.get("growth_exp", 0)):
		GameState.set_pet_and_care_stats(pet_id, pet, care_stats)
		return false
	care_stats["last_touch_effect_at"] = now_seconds
	pet["last_touched_at"] = Time.get_datetime_string_from_system()
	if not GameState.set_pet_and_care_stats(pet_id, pet, care_stats):
		return false
	_log_int_change("mood", old_mood, int(pet.get("mood", 0)))
	_log_int_change("growth_exp", old_exp, int(pet.get("growth_exp", 0)))
	if reached_cap_now and str(care_stats.get("touch_cap_notified_date", "")) != window_id:
		care_stats["touch_cap_notified_date"] = window_id
		GameState.set_pet_and_care_stats(pet_id, pet, care_stats)
		RuntimeLogger.log_info_throttled("touch_growth_cap_%s" % pet_id, "Touch growth cap reached: %d/%d" % [int(care_stats["touch_growth_exp_today"]), cap])
	return true


static func clean_tank() -> bool:
	var aquarium: Dictionary = GameState.get_aquarium()
	var old_cleanliness: int = int(aquarium.get("cleanliness", 0))
	var target_cleanliness: int = int(GameApp.get_balance_value("cleanliness_after_clean", 100))
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
	var elapsed: float = max(days, 0.0)
	for pet_id in GameState.get_pet_ids():
		var pet: Dictionary = GameState.get_pet(pet_id)
		var species: Dictionary = _get_table_entry("species", str(pet.get("species_id", "normal_jellycat")))
		var old_health: String = str(pet.get("health", "healthy"))
		pet["hunger"] = max(0, int(pet.get("hunger", 0)) - int(round(float(species.get("hunger_decay_per_day", 15)) * elapsed)))
		pet["mood"] = max(0, int(pet.get("mood", 0)) - int(round(float(species.get("mood_decay_per_day", 8)) * elapsed)))
		_apply_sickness_check(pet, old_health)
		GameState.set_pet(pet_id, pet)
	var aquarium: Dictionary = GameState.get_aquarium()
	var decay: float = 12.0
	var ids: Array[String] = GameState.get_pet_ids()
	if not ids.is_empty():
		var species: Dictionary = _get_table_entry("species", str(GameState.get_pet(ids[0]).get("species_id", "normal_jellycat")))
		decay = float(species.get("cleanliness_decay_per_day", 12))
	GameState.set_aquarium_cleanliness(int(aquarium.get("cleanliness", 100)) - int(round(decay * elapsed)))


static func apply_offline_care_decay(elapsed_seconds: int) -> void:
	var days: float = TimeManager.days_from_seconds(float(max(elapsed_seconds, 0)))
	if days <= 0.0:
		return
	for pet_id in GameState.get_pet_ids():
		var pet: Dictionary = GameState.get_pet(pet_id)
		var species: Dictionary = _get_table_entry("species", str(pet.get("species_id", "normal_jellycat")))
		var old_hunger: int = int(pet.get("hunger", 0))
		var old_mood: int = int(pet.get("mood", 0))
		var old_health: String = str(pet.get("health", "healthy"))
		pet["hunger"] = clampi(old_hunger - int(round(float(species.get("hunger_decay_per_day", 15)) * days)), 0, 100)
		pet["mood"] = clampi(old_mood - int(round(float(species.get("mood_decay_per_day", 8)) * days)), 0, 100)
		_apply_sickness_check(pet, old_health)
		GameState.set_pet(pet_id, pet)
		_log_int_change("hunger", old_hunger, int(pet.get("hunger", 0)))
		_log_int_change("mood", old_mood, int(pet.get("mood", 0)))
		_log_string_change("health", old_health, str(pet.get("health", "healthy")))
	var aquarium: Dictionary = GameState.get_aquarium()
	var cleanliness_decay: float = 12.0
	var pet_ids: Array[String] = GameState.get_pet_ids()
	if not pet_ids.is_empty():
		var first_species: Dictionary = _get_table_entry("species", str(GameState.get_pet(pet_ids[0]).get("species_id", "normal_jellycat")))
		cleanliness_decay = float(first_species.get("cleanliness_decay_per_day", 12))
	var old_cleanliness: int = int(aquarium.get("cleanliness", 100))
	var next_cleanliness: int = clampi(old_cleanliness - int(round(cleanliness_decay * days)), 0, 100)
	GameState.set_aquarium_cleanliness(next_cleanliness)
	_log_int_change("tank cleanliness", old_cleanliness, next_cleanliness)


static func _consume_food_for_pet(pet_id: String, item_id: String, consume_item: bool) -> bool:
	var item: Dictionary = _get_table_entry("items", item_id)
	var pet: Dictionary = GameState.get_pet(pet_id)
	if item.is_empty() or pet.is_empty():
		RuntimeLogger.log_error("Invalid food target: %s" % pet_id)
		return false
	var old_hunger: int = int(pet.get("hunger", 0))
	var old_mood: int = int(pet.get("mood", 0))
	var old_exp: int = int(pet.get("growth_exp", 0))
	if old_hunger >= 100 and old_mood >= 100 and int(item.get("growth_exp_add", 0)) <= 0:
		return false
	if consume_item:
		var old_count: int = GameState.get_inventory_count(item_id)
		if old_count <= 0:
			RuntimeLogger.log_info("No item available: %s" % item_id)
			return false
		GameState.set_inventory_count(item_id, old_count - 1)
	pet["hunger"] = _clamp_stat(old_hunger + int(item.get("hunger_add", 0)), "max_hunger")
	pet["mood"] = _clamp_stat(old_mood + int(item.get("mood_add", 0)), "max_mood")
	pet["growth_exp"] = old_exp + int(item.get("growth_exp_add", 0))
	pet["last_fed_at"] = Time.get_datetime_string_from_system()
	if not GameState.set_pet(pet_id, pet):
		if consume_item:
			GameState.set_inventory_count(item_id, GameState.get_inventory_count(item_id) + 1)
		return false
	_log_int_change("hunger", old_hunger, int(pet.get("hunger", 0)))
	_log_int_change("mood", old_mood, int(pet.get("mood", 0)))
	_log_int_change("growth_exp", old_exp, int(pet.get("growth_exp", 0)))
	return true


static func _get_table_entry(table_name: String, key: String) -> Dictionary:
	var entry: Variant = GameApp.get_table(table_name).get(key, {})
	return entry as Dictionary if entry is Dictionary else {}


static func _saved_touch_window_start(care_stats: Dictionary) -> float:
	var raw_start: String = str(care_stats.get("touch_exp_date", ""))
	if raw_start.is_valid_float():
		return raw_start.to_float()
	var old_timestamp: String = raw_start.replace("T", " ")
	if Time.get_unix_time_from_datetime_string(old_timestamp) > 0:
		return Time.get_unix_time_from_datetime_string(old_timestamp)
	return 0.0


static func _apply_sickness_check(pet: Dictionary, old_health: String) -> void:
	if str(pet.get("health", "healthy")) == "sick":
		return
	if int(pet.get("hunger", 0)) > 0 and int(pet.get("mood", 0)) > 0:
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	if rng.randf() < 0.25:
		pet["health"] = "sick"


static func _clamp_stat(value: int, max_key: String) -> int:
	var maximum: int = int(GameApp.get_balance_value(max_key, 100))
	return clampi(value, 0, maximum)


static func _log_int_change(label: String, old_value: int, new_value: int) -> void:
	if old_value != new_value:
		RuntimeLogger.log_state("%s: %d -> %d" % [label, old_value, new_value])


static func _log_string_change(label: String, old_value: String, new_value: String) -> void:
	if old_value != new_value:
		RuntimeLogger.log_state("%s: %s -> %s" % [label, old_value, new_value])
