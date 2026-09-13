extends Node

signal state_changed

const SAVE_VERSION: String = "0.1.0"

var data: Dictionary = {}

func _ready() -> void:
	reset_to_default()


func reset_to_default() -> void:
	var now: String = Time.get_datetime_string_from_system()
	data = {
		"save_version": SAVE_VERSION,
		"player": {
			"player_id": "local_player",
			"created_at": now
		},
		"egg": null,
		"jellycat": null,
		"currency": {
			"bubble_coin": 20
		},
		"inventory": {
			"food_basic": 5,
			"cookie_basic": 3,
			"medicine_basic": 1
		},
		"care_stats": {
			"touch_growth_exp_today": 0,
			"touch_exp_date": "",
			"last_touch_effect_at": 0.0,
			"touch_cap_notified_date": ""
		},
		"daily_claim": {
			"last_free_food_date": ""
		},
		"unlocked_species": [
			"normal_jellycat"
		],
		"timestamps": {
			"last_saved_at": "",
			"last_opened_at": now,
			"last_passive_coin_at": now
		}
	}
	emit_signal("state_changed")


func set_data(next_data: Dictionary) -> void:
	data = next_data.duplicate(true)
	_ensure_schema()
	emit_signal("state_changed")


func mark_changed(auto_save: bool = true) -> void:
	emit_signal("state_changed")
	if auto_save and SaveManager != null:
		SaveManager.request_save()


func get_egg() -> Variant:
	return data.get("egg")


func set_egg(egg_data: Variant) -> void:
	data["egg"] = egg_data
	mark_changed()


func get_jellycat() -> Variant:
	return data.get("jellycat")


func set_jellycat(jellycat_data: Variant) -> void:
	data["jellycat"] = jellycat_data
	mark_changed()


func set_jellycat_and_care_stats(jellycat_data: Dictionary, care_stats: Dictionary) -> void:
	data["jellycat"] = jellycat_data
	data["care_stats"] = care_stats
	mark_changed()


func get_currency(currency_id: String) -> int:
	var currency: Dictionary = _get_or_create_dictionary("currency")
	return int(currency.get(currency_id, 0))


func set_currency(currency_id: String, amount: int) -> void:
	var currency: Dictionary = _get_or_create_dictionary("currency")
	currency[currency_id] = max(amount, 0)
	mark_changed()


func get_inventory_count(item_id: String) -> int:
	var inventory: Dictionary = _get_or_create_dictionary("inventory")
	return int(inventory.get(item_id, 0))


func set_inventory_count(item_id: String, count: int) -> void:
	var inventory: Dictionary = _get_or_create_dictionary("inventory")
	inventory[item_id] = max(count, 0)
	mark_changed()


func get_care_stats() -> Dictionary:
	return _get_or_create_dictionary("care_stats").duplicate(true)


func set_care_stats(care_stats: Dictionary) -> void:
	data["care_stats"] = care_stats
	mark_changed()


func get_daily_claim() -> Dictionary:
	return _get_or_create_dictionary("daily_claim").duplicate(true)


func set_daily_claim(daily_claim: Dictionary) -> void:
	data["daily_claim"] = daily_claim
	mark_changed()


func get_timestamp(key: String) -> String:
	var timestamps: Dictionary = _get_or_create_dictionary("timestamps")
	return str(timestamps.get(key, ""))


func set_timestamp(key: String, value: String, auto_save: bool = true) -> void:
	var timestamps: Dictionary = _get_or_create_dictionary("timestamps")
	timestamps[key] = value
	mark_changed(auto_save)


func has_unhatched_egg() -> bool:
	var egg: Variant = get_egg()
	return egg is Dictionary and not bool(egg.get("is_hatched", false))


func has_jellycat() -> bool:
	return get_jellycat() is Dictionary


func _ensure_schema() -> void:
	if not data.has("save_version"):
		data["save_version"] = SAVE_VERSION
	if not data.has("player"):
		data["player"] = {"player_id": "local_player", "created_at": Time.get_datetime_string_from_system()}
	if not data.has("currency"):
		data["currency"] = {"bubble_coin": 20}
	else:
		var currency: Dictionary = _get_or_create_dictionary("currency")
		if not currency.has("bubble_coin"):
			currency["bubble_coin"] = 20
	if not data.has("inventory"):
		data["inventory"] = {"food_basic": 5, "cookie_basic": 3, "medicine_basic": 1}
	else:
		var inventory: Dictionary = _get_or_create_dictionary("inventory")
		if not inventory.has("food_basic"):
			inventory["food_basic"] = 5
		if not inventory.has("cookie_basic"):
			inventory["cookie_basic"] = 3
		if not inventory.has("medicine_basic"):
			inventory["medicine_basic"] = 1
	if not data.has("care_stats"):
		data["care_stats"] = {}
	var care_stats: Dictionary = _get_or_create_dictionary("care_stats")
	if not care_stats.has("touch_growth_exp_today"):
		care_stats["touch_growth_exp_today"] = 0
	if not care_stats.has("touch_exp_date"):
		care_stats["touch_exp_date"] = ""
	if not care_stats.has("last_touch_effect_at"):
		care_stats["last_touch_effect_at"] = 0.0
	if not care_stats.has("touch_cap_notified_date"):
		care_stats["touch_cap_notified_date"] = ""
	if not data.has("daily_claim"):
		data["daily_claim"] = {}
	var daily_claim: Dictionary = _get_or_create_dictionary("daily_claim")
	if not daily_claim.has("last_free_food_date"):
		daily_claim["last_free_food_date"] = ""
	_ensure_jellycat_schema()
	if not data.has("unlocked_species"):
		data["unlocked_species"] = ["normal_jellycat"]
	if not data.has("timestamps"):
		data["timestamps"] = {}
	var now: String = Time.get_datetime_string_from_system()
	var timestamps: Dictionary = _get_or_create_dictionary("timestamps")
	if not timestamps.has("last_saved_at"):
		timestamps["last_saved_at"] = ""
	timestamps["last_opened_at"] = now
	if not timestamps.has("last_passive_coin_at"):
		timestamps["last_passive_coin_at"] = now


func _ensure_jellycat_schema() -> void:
	var jellycat: Variant = data.get("jellycat")
	if not (jellycat is Dictionary):
		return
	var jellycat_data: Dictionary = jellycat as Dictionary
	var species_id: String = str(jellycat_data.get("species_id", "normal_jellycat"))
	var species: Variant = GameApp.get_table("species").get(species_id, {})
	var species_data: Dictionary = {}
	if species is Dictionary:
		species_data = species as Dictionary
	if not jellycat_data.has("id"):
		jellycat_data["id"] = "jc_001"
	if not jellycat_data.has("species_id"):
		jellycat_data["species_id"] = species_id
	if not jellycat_data.has("stage"):
		jellycat_data["stage"] = 1
	jellycat_data["stage"] = clamp(int(jellycat_data.get("stage", 1)), 1, int(species_data.get("max_stage", 5)))
	if not jellycat_data.has("hunger"):
		jellycat_data["hunger"] = int(species_data.get("default_hunger", 80))
	if not jellycat_data.has("mood"):
		jellycat_data["mood"] = int(species_data.get("default_mood", 70))
	if not jellycat_data.has("cleanliness"):
		jellycat_data["cleanliness"] = int(species_data.get("default_cleanliness", 100))
	if not jellycat_data.has("health"):
		jellycat_data["health"] = "healthy"
	if str(jellycat_data.get("health", "healthy")) == "needs_care":
		jellycat_data["health"] = "sick"
	if not jellycat_data.has("growth_exp"):
		jellycat_data["growth_exp"] = 0
	jellycat_data["hunger"] = clamp(int(jellycat_data.get("hunger", 0)), 0, 100)
	jellycat_data["mood"] = clamp(int(jellycat_data.get("mood", 0)), 0, 100)
	jellycat_data["cleanliness"] = clamp(int(jellycat_data.get("cleanliness", 0)), 0, 100)
	data["jellycat"] = jellycat_data


func _get_or_create_dictionary(key: String) -> Dictionary:
	var value: Variant = data.get(key, {})
	if value is Dictionary:
		return value as Dictionary
	data[key] = {}
	return data[key] as Dictionary


func to_save_dict() -> Dictionary:
	return data.duplicate(true)
