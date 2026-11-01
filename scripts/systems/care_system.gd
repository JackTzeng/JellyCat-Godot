extends Node
class_name CareSystem

# Seconds of online hunger decay not yet converted into a whole hunger point.
static var _online_hunger_carry_seconds: float = 0.0


# Per-pet mood decay carry: {pet_id: {"state": int, "carry": int}}. In-memory only (no save schema change).
# state: 0 = not hungry (no decay, carry stays 0), 1 = hungry (0 < hunger <= hungry_hunger_max), 2 = starving (hunger == 0).
# Leaving a state resets the carry to 0 so remainders never accumulate across states.
static var _online_mood_carry: Dictionary = {}


static func reset_online_hunger_carry() -> void:
	_online_hunger_carry_seconds = 0.0
	_online_mood_carry.clear()


static func reset_online_mood_carry() -> void:
	_online_mood_carry.clear()


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
	var gameplay_now_seconds: float = TimeManager.gameplay_now_seconds(now_seconds)
	var cooldown: float = maxf(float(GameApp.get_balance_value("touch_cooldown_seconds")), 0.0)
	var last_touch: float = float(care_stats.get("last_touch_effect_at", 0.0))
	if now_seconds - last_touch < cooldown:
		RuntimeLogger.log_info_throttled("touch_cooldown_%s" % pet_id, "Touch ignored for %s: cooldown" % pet_id)
		return false
	var reset_seconds: float = maxf(float(GameApp.get_balance_value("touch_exp_reset_seconds")), 1.0)
	var window_started_at: float = float(care_stats.get("touch_exp_hour_started_at", 0.0))
	if window_started_at <= 0.0 or gameplay_now_seconds < window_started_at or gameplay_now_seconds - window_started_at >= reset_seconds:
		window_started_at = gameplay_now_seconds
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
	RuntimeLogger.log_state("%s health: %s -> healthy" % [pet_id, old_health])
	return true


static func simulate_days(days: float) -> void:
	apply_offline_care_decay(int(round(maxf(days, 0.0) * TimeManager.SECONDS_PER_DAY)))


static func apply_online_care_decay(elapsed_seconds: int) -> void:
	if elapsed_seconds <= 0:
		return
	var seconds_per_minute: int = max(int(GameApp.get_balance_value("seconds_per_minute")), 1)
	var minutes: int = int(floor(float(max(elapsed_seconds, 0)) / float(seconds_per_minute)))
	_apply_online_cleanliness_decay(elapsed_seconds)
	_apply_sickness_for_dirty_tank(int(GameState.get_aquarium().get("cleanliness", 0)))
	if minutes <= 0:
		return
	# Hunger falls by whole points (hunger_decay_points) every hunger_decay_interval_seconds.
	# The partial interval is carried in _online_hunger_carry_seconds so no fraction is lost.
	var hunger_points_per_interval: int = max(int(GameApp.get_balance_value("hunger_decay_points", 1)), 0)
	var hunger_interval: float = maxf(float(GameApp.get_balance_value("hunger_decay_interval_seconds", 120)), 1.0)
	var hunger_decay_by_minute: Array[int] = []
	for _step in range(minutes):
		_online_hunger_carry_seconds += float(seconds_per_minute)
		var interval_count: int = int(floor(_online_hunger_carry_seconds / hunger_interval + 0.000001))
		_online_hunger_carry_seconds = maxf(_online_hunger_carry_seconds - float(interval_count) * hunger_interval, 0.0)
		hunger_decay_by_minute.append(interval_count * hunger_points_per_interval)
	var hungry_max: int = max(int(GameApp.get_balance_value("hungry_hunger_max")), 0)
	# Mood falls by whole points (mood_decay_*_points) every mood_decay_*_interval_seconds while hungry / starving.
	var hungry_mood_points: int = max(int(GameApp.get_balance_value("mood_decay_hungry_points", 1)), 0)
	var hungry_mood_interval: int = max(int(GameApp.get_balance_value("mood_decay_hungry_interval_seconds", 600)), 1)
	var starving_mood_points: int = max(int(GameApp.get_balance_value("mood_decay_starving_points", 1)), 0)
	var starving_mood_interval: int = max(int(GameApp.get_balance_value("mood_decay_starving_interval_seconds", 300)), 1)
	for pet_id in GameState.get_pet_ids():
		var pet: Dictionary = GameState.get_pet(pet_id)
		var old_hunger: int = int(pet.get("hunger", 0))
		var old_mood: int = int(pet.get("mood", 0))
		var hunger: int = old_hunger
		var mood: int = old_mood
		var mood_entry: Dictionary = _online_mood_carry.get(pet_id, {"state": 0, "carry": 0}) as Dictionary
		var mood_state: int = int(mood_entry.get("state", 0))
		var mood_carry: int = int(mood_entry.get("carry", 0))
		for minute_index in range(minutes):
			var step_state: int = 2 if hunger <= 0 else (1 if hunger <= hungry_max else 0)
			if step_state != mood_state:
				mood_state = step_state
				mood_carry = 0
			if step_state != 0:
				var step_interval: int = starving_mood_interval if step_state == 2 else hungry_mood_interval
				var step_points: int = starving_mood_points if step_state == 2 else hungry_mood_points
				mood_carry += seconds_per_minute
				var mood_intervals: int = int(floor(float(mood_carry) / float(step_interval)))
				mood_carry -= mood_intervals * step_interval
				mood = maxi(0, mood - mood_intervals * step_points)
			if hunger > 0:
				hunger = maxi(0, hunger - hunger_decay_by_minute[minute_index])
		_online_mood_carry[pet_id] = {"state": mood_state, "carry": mood_carry}
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
	var sick_threshold: int = int(GameApp.get_balance_value("sick_cleanliness_threshold", 0))
	var configured_cleanliness_floor: int = int(GameApp.get_balance_value("offline_cleanliness_floor", sick_threshold + 1))
	var cleanliness_floor: int = clampi(maxi(configured_cleanliness_floor, sick_threshold + 1), 0, int(GameApp.get_balance_value("max_cleanliness")))
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
	var next_cleanliness: int = clampi(maxi(old_cleanliness - int(round(cleanliness_decay * days)), cleanliness_floor), cleanliness_floor, max_cleanliness)
	GameState.set_aquarium_cleanliness(next_cleanliness)
	_log_int_change("tank cleanliness", old_cleanliness, next_cleanliness)
	if next_cleanliness <= sick_threshold:
		_apply_sickness_for_dirty_tank(next_cleanliness)


static func _apply_online_cleanliness_decay(elapsed_seconds: int) -> void:
	var pet_ids: Array[String] = GameState.get_pet_ids()
	if pet_ids.is_empty():
		return
	var first_pet: Dictionary = GameState.get_pet(pet_ids[0])
	var species: Dictionary = _get_table_entry("species", str(first_pet.get("species_id", "normal_jellycat")))
	var decay_per_day: float = maxf(float(species.get("cleanliness_decay_per_day", 0.0)), 0.0)
	var decay_points: int = TimeManager.consume_online_cleanliness_decay(float(elapsed_seconds), decay_per_day)
	if decay_points <= 0:
		return
	var old_cleanliness: int = int(GameState.get_aquarium().get("cleanliness", GameApp.get_balance_value("max_cleanliness")))
	GameState.set_aquarium_cleanliness(maxi(0, old_cleanliness - decay_points))
	_log_int_change("tank cleanliness", old_cleanliness, maxi(0, old_cleanliness - decay_points))


static func _apply_sickness_for_dirty_tank(cleanliness: int) -> void:
	var threshold: int = int(GameApp.get_balance_value("sick_cleanliness_threshold", 0))
	if cleanliness > threshold:
		return
	for pet_id in GameState.get_pet_ids():
		var pet: Dictionary = GameState.get_pet(pet_id)
		if str(pet.get("health", "healthy")) != "healthy":
			continue
		pet["health"] = "sick"
		if GameState.set_pet(pet_id, pet):
			RuntimeLogger.log_state("%s health healthy -> sick: tank cleanliness %d <= %d" % [pet_id, cleanliness, threshold])


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
