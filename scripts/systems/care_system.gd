extends Node

class_name CareSystem

static func feed_food() -> bool:
	return _consume_item("food_basic")


static func feed_cookie() -> bool:
	return _consume_item("cookie_basic")


static func touch_pet() -> bool:
	var jellycat: Dictionary = _get_jellycat()
	if jellycat.is_empty():
		RuntimeLogger.log_error("No jellycat found")
		return false
	var care_stats: Dictionary = GameState.get_care_stats()
	var now_seconds: float = Time.get_unix_time_from_system()
	var cooldown: float = float(GameApp.get_balance_value("touch_cooldown_seconds", 0.5))
	var last_touch: float = float(care_stats.get("last_touch_effect_at", 0.0))
	if now_seconds - last_touch < cooldown:
		return false
	var reset_seconds: float = max(float(GameApp.get_balance_value("touch_exp_reset_seconds", 600)), 1.0)
	var window_started_at: float = _saved_touch_window_start(care_stats)
	if window_started_at <= 0.0 or now_seconds < window_started_at or now_seconds - window_started_at >= reset_seconds:
		window_started_at = now_seconds
		care_stats["touch_growth_exp_today"] = 0
		care_stats["touch_exp_date"] = str(window_started_at)
		care_stats["touch_cap_notified_date"] = ""
	var window_id: String = str(window_started_at)
	var old_mood: int = int(jellycat.get("mood", 0))
	var old_exp: int = int(jellycat.get("growth_exp", 0))
	jellycat["mood"] = _clamp_stat(old_mood + int(GameApp.get_balance_value("touch_mood_add", 5)), "max_mood")
	var cap: int = max(int(GameApp.get_balance_value("touch_growth_exp_cap", 20)), 0)
	var exp_today: int = max(int(care_stats.get("touch_growth_exp_today", 0)), 0)
	var reached_cap_now: bool = false
	if exp_today < cap:
		var exp_add: int = min(int(GameApp.get_balance_value("touch_growth_exp_add", 1)), cap - exp_today)
		jellycat["growth_exp"] = old_exp + exp_add
		care_stats["touch_growth_exp_today"] = exp_today + exp_add
		if int(care_stats["touch_growth_exp_today"]) >= cap and str(care_stats.get("touch_cap_notified_date", "")) != window_id:
			reached_cap_now = true
			care_stats["touch_cap_notified_date"] = window_id
	else:
		if str(care_stats.get("touch_cap_notified_date", "")) != window_id:
			RuntimeLogger.log_info_throttled("touch_growth_cap", "Touch growth cap reached: %d/%d; resets every 10 minutes" % [exp_today, cap])
			care_stats["touch_cap_notified_date"] = window_id
			GameState.set_care_stats(care_stats)
	if old_mood == int(jellycat.get("mood", 0)) and old_exp == int(jellycat.get("growth_exp", 0)):
		return false
	RuntimeLogger.log_action("Touch clicked")
	care_stats["last_touch_effect_at"] = now_seconds
	jellycat["last_touched_at"] = Time.get_datetime_string_from_system()
	GameState.set_jellycat_and_care_stats(jellycat, care_stats)
	_log_int_change("mood", old_mood, int(jellycat.get("mood", 0)))
	_log_int_change("growth_exp", old_exp, int(jellycat.get("growth_exp", 0)))
	if reached_cap_now:
		RuntimeLogger.log_info_throttled("touch_growth_cap", "Touch growth cap reached: %d/%d; resets every 10 minutes" % [int(care_stats["touch_growth_exp_today"]), cap])
	return true


static func clean_tank() -> bool:
	var jellycat: Dictionary = _get_jellycat()
	if jellycat.is_empty():
		RuntimeLogger.log_error("No jellycat found")
		return false
	var old_cleanliness: int = int(jellycat.get("cleanliness", 0))
	var target_cleanliness: int = int(GameApp.get_balance_value("cleanliness_after_clean", 100))
	if old_cleanliness >= target_cleanliness:
		RuntimeLogger.log_info_throttled("tank_already_clean", "Tank is already clean")
		return false
	jellycat["cleanliness"] = target_cleanliness
	jellycat["last_cleaned_at"] = Time.get_datetime_string_from_system()
	GameState.set_jellycat(jellycat)
	_log_int_change("cleanliness", old_cleanliness, int(jellycat.get("cleanliness", 0)))
	return true


static func give_medicine() -> bool:
	var jellycat: Dictionary = _get_jellycat()
	if jellycat.is_empty():
		RuntimeLogger.log_error("No jellycat found")
		return false
	if str(jellycat.get("health", "healthy")) == "healthy":
		RuntimeLogger.log_info_throttled("jellycat_already_healthy", "JellyCat is already healthy")
		return false
	if GameState.get_inventory_count("medicine_basic") <= 0:
		RuntimeLogger.log_error_throttled("not_enough_item_medicine_basic", "Not enough item: medicine_basic")
		return false
	RuntimeLogger.log_action("Medicine used")
	var old_count: int = GameState.get_inventory_count("medicine_basic")
	GameState.set_inventory_count("medicine_basic", old_count - 1)
	_log_int_change("medicine_basic count", old_count, GameState.get_inventory_count("medicine_basic"))
	var old_health: String = str(jellycat.get("health", "healthy"))
	jellycat["health"] = "healthy"
	GameState.set_jellycat(jellycat)
	_log_string_change("health", old_health, str(jellycat.get("health", "healthy")))
	return true


static func simulate_days(days: float) -> void:
	var jellycat: Dictionary = _get_jellycat()
	if jellycat.is_empty():
		RuntimeLogger.log_error("No jellycat found")
		return
	var species: Dictionary = _get_table_entry("species", str(jellycat.get("species_id", "normal_jellycat")))
	jellycat["hunger"] = max(0, int(jellycat.get("hunger", 0)) - int(round(float(species.get("hunger_decay_per_day", 15)) * days)))
	jellycat["mood"] = max(0, int(jellycat.get("mood", 0)) - int(round(float(species.get("mood_decay_per_day", 8)) * days)))
	jellycat["cleanliness"] = max(0, int(jellycat.get("cleanliness", 0)) - int(round(float(species.get("cleanliness_decay_per_day", 12)) * days)))
	if int(jellycat["hunger"]) <= 0 or int(jellycat["cleanliness"]) <= 0:
		jellycat["health"] = "sick"
	GameState.set_jellycat(jellycat)


static func apply_offline_care_decay(elapsed_seconds: int) -> void:
	if elapsed_seconds < 3600:
		return
	var jellycat: Dictionary = _get_jellycat()
	if jellycat.is_empty():
		return
	var days: float = TimeManager.days_from_seconds(float(elapsed_seconds))
	var species: Dictionary = _get_table_entry("species", str(jellycat.get("species_id", "normal_jellycat")))
	var old_hunger: int = int(jellycat.get("hunger", 0))
	var old_mood: int = int(jellycat.get("mood", 0))
	var old_cleanliness: int = int(jellycat.get("cleanliness", 0))
	var old_health: String = str(jellycat.get("health", "healthy"))
	jellycat["hunger"] = clamp(old_hunger - int(round(float(species.get("hunger_decay_per_day", 15)) * days)), 0, 100)
	jellycat["mood"] = clamp(old_mood - int(round(float(species.get("mood_decay_per_day", 8)) * days)), 0, 100)
	jellycat["cleanliness"] = clamp(old_cleanliness - int(round(float(species.get("cleanliness_decay_per_day", 12)) * days)), 0, 100)
	_apply_sickness_check(jellycat, old_health)
	GameState.set_jellycat(jellycat)
	RuntimeLogger.log_info("Offline care decay applied: %.1f hours" % (float(elapsed_seconds) / 3600.0))
	_log_int_change("hunger", old_hunger, int(jellycat.get("hunger", 0)))
	_log_int_change("mood", old_mood, int(jellycat.get("mood", 0)))
	_log_int_change("cleanliness", old_cleanliness, int(jellycat.get("cleanliness", 0)))
	_log_string_change("health", old_health, str(jellycat.get("health", "healthy")))


static func _consume_item(item_id: String) -> bool:
	if GameState.get_inventory_count(item_id) <= 0:
		RuntimeLogger.log_error_throttled("not_enough_item_%s" % item_id, "Not enough item: %s" % item_id)
		return false
	var item: Dictionary = _get_table_entry("items", item_id)
	var jellycat: Dictionary = _get_jellycat()
	if item.is_empty() or jellycat.is_empty():
		if item.is_empty():
			RuntimeLogger.log_error("Inventory item missing: %s" % item_id)
		else:
			RuntimeLogger.log_error("No jellycat found")
		return false
	var old_hunger: int = int(jellycat.get("hunger", 0))
	var old_mood: int = int(jellycat.get("mood", 0))
	var old_exp: int = int(jellycat.get("growth_exp", 0))
	var old_count: int = GameState.get_inventory_count(item_id)
	GameState.set_inventory_count(item_id, old_count - 1)
	_log_int_change("%s count" % item_id, old_count, GameState.get_inventory_count(item_id))
	jellycat["hunger"] = _clamp_stat(int(jellycat.get("hunger", 0)) + int(item.get("hunger_add", 0)), "max_hunger")
	jellycat["mood"] = _clamp_stat(int(jellycat.get("mood", 0)) + int(item.get("mood_add", 0)), "max_mood")
	jellycat["growth_exp"] = int(jellycat.get("growth_exp", 0)) + int(item.get("growth_exp_add", 0))
	jellycat["last_fed_at"] = Time.get_datetime_string_from_system()
	GameState.set_jellycat(jellycat)
	_log_int_change("hunger", old_hunger, int(jellycat.get("hunger", 0)))
	_log_int_change("mood", old_mood, int(jellycat.get("mood", 0)))
	_log_int_change("growth_exp", old_exp, int(jellycat.get("growth_exp", 0)))
	return true


static func _get_jellycat() -> Dictionary:
	var jellycat: Variant = GameState.get_jellycat()
	if jellycat is Dictionary:
		return jellycat.duplicate(true)
	return {}


static func _get_table_entry(table_name: String, key: String) -> Dictionary:
	var entry: Variant = GameApp.get_table(table_name).get(key, {})
	if entry is Dictionary:
		return entry
	return {}


static func _saved_touch_window_start(care_stats: Dictionary) -> float:
	var raw_start: String = str(care_stats.get("touch_exp_date", ""))
	if not raw_start.is_valid_float():
		return 0.0
	return raw_start.to_float()


static func _apply_sickness_check(jellycat: Dictionary, old_health: String) -> void:
	if int(jellycat.get("cleanliness", 100)) >= 30:
		return
	if old_health != "healthy":
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	if rng.randf() < 0.2:
		jellycat["health"] = "sick"
		RuntimeLogger.log_error("JellyCat became sick due to low cleanliness")


static func _clamp_stat(value: int, max_key: String) -> int:
	return clamp(value, 0, int(GameApp.get_balance_value(max_key, 100)))


static func _log_int_change(label: String, old_value: int, new_value: int) -> void:
	if old_value != new_value:
		RuntimeLogger.log_state("%s changed: %d -> %d" % [label, old_value, new_value])


static func _log_string_change(label: String, old_value: String, new_value: String) -> void:
	if old_value != new_value:
		RuntimeLogger.log_state("%s changed: %s -> %s" % [label, old_value, new_value])
