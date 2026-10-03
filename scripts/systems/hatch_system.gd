extends Node

class_name HatchSystem

const STARTER_PERSONALITIES: Array[String] = ["curious", "affectionate", "sleepy"]


static func tap_egg(egg_id: String) -> Dictionary:
	var egg: Dictionary = GameState.get_nursery_egg(egg_id)
	if egg.is_empty():
		RuntimeLogger.log_error("No egg found for id: %s" % egg_id)
		return {}
	var old_clicks: int = int(egg.get("current_clicks", 0))
	egg["current_clicks"] = min(old_clicks + 1, int(egg.get("required_clicks", 10)))
	if old_clicks != int(egg.get("current_clicks", 0)):
		RuntimeLogger.log_state("egg current_clicks changed: %d -> %d" % [old_clicks, int(egg.get("current_clicks", 0))])
	if int(egg["current_clicks"]) >= int(egg.get("required_clicks", 10)):
		egg["is_hatched"] = false
		if not GameState.update_nursery_egg(egg_id, egg):
			return {}
		var pet: Dictionary = create_pet_from_egg(egg_id)
		if pet.is_empty():
			return egg
		egg["is_hatched"] = true
		return egg
	else:
		egg["is_hatched"] = false
		GameState.update_nursery_egg(egg_id, egg)
	return egg


static func create_pet_from_egg(egg_id: String) -> Dictionary:
	var egg: Dictionary = GameState.get_nursery_egg(egg_id)
	if egg.is_empty() or int(egg.get("current_clicks", 0)) < int(egg.get("required_clicks", 10)):
		return {}
	var species_id: String = str(egg.get("species_id", "normal_jellycat"))
	var species: Dictionary = _get_table_entry("species", species_id)
	var now: String = Time.get_datetime_string_from_system()
	var pet_id: String = str(egg.get("pet_id", ""))
	if pet_id.is_empty() or not GameState.get_pet(pet_id).is_empty():
		pet_id = _next_pet_id()
		egg["pet_id"] = pet_id
	var pet_number: int = GameState.get_pet_ids().size()
	var personality_id: String = str(egg.get("personality_id", ""))
	if personality_id.is_empty():
		personality_id = STARTER_PERSONALITIES[pet_number % STARTER_PERSONALITIES.size()]
	if not GameApp.get_table("personalities").has(personality_id):
		personality_id = "curious"
	egg["personality_id"] = personality_id
	egg["pet_id"] = pet_id
	if not GameState.update_nursery_egg(egg_id, egg):
		return {}
	var personality: Dictionary = GameApp.get_table("personalities").get(personality_id, {}) as Dictionary
	var pet: Dictionary = {
		"pet_id": pet_id,
		"species_id": species_id,
		"nickname": "%s水母喵" % str(personality.get("display_name", "好奇")),
		"personality_id": personality_id,
		"stage": 1,
		"hunger": int(species.get("default_hunger", 80)),
		"mood": int(species.get("default_mood", 70)),
		"health": "healthy",
		"growth_exp": 0,
		"vitality": 100,
		"visual_params": {},
		"care_stats": {
			"touch_growth_exp_today": 0,
			"touch_exp_date": "",
			"last_touch_effect_at": 0.0,
			"touch_cap_notified_date": ""
		},
		"created_at": now,
		"last_fed_at": "",
		"last_touched_at": "",
		"last_cleaned_at": ""
	}
	if not GameState.hatch_egg(egg_id, pet):
		RuntimeLogger.log_error("Hatch failed: aquarium transaction rejected egg %s" % egg_id)
		return {}
	GameState.ensure_starter_eggs()
	GameState.set_selected_pet_id(pet_id)
	RuntimeLogger.log_state("JellyCat created: %s (%s)" % [pet_id, personality_id])
	SaveManager.save_game()
	return GameState.get_pet(pet_id)


static func _next_pet_id() -> String:
	var candidate: int = 1
	while not GameState.get_pet("jc_%03d" % candidate).is_empty():
		candidate += 1
	return "jc_%03d" % candidate


static func _get_table_entry(table_name: String, key: String) -> Dictionary:
	var entry: Variant = GameApp.get_table(table_name).get(key, {})
	if entry is Dictionary:
		return entry
	return {}
