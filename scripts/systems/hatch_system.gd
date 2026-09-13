extends Node

class_name HatchSystem

static func tap_egg() -> Dictionary:
	var egg: Variant = GameState.get_egg()
	if not (egg is Dictionary):
		RuntimeLogger.log_error("No egg found")
		egg = EggSystem.create_starter_egg()
	var old_clicks: int = int(egg.get("current_clicks", 0))
	egg["current_clicks"] = min(old_clicks + 1, int(egg.get("required_clicks", 10)))
	if old_clicks != int(egg.get("current_clicks", 0)):
		RuntimeLogger.log_state("egg current_clicks changed: %d -> %d" % [old_clicks, int(egg.get("current_clicks", 0))])
	if int(egg["current_clicks"]) >= int(egg.get("required_clicks", 10)):
		egg["is_hatched"] = true
		GameState.set_egg(egg)
		create_jellycat_from_egg(egg)
	else:
		GameState.set_egg(egg)
	return egg


static func create_jellycat_from_egg(egg: Dictionary) -> Dictionary:
	var species_id: String = str(egg.get("species_id", "normal_jellycat"))
	var species: Dictionary = _get_table_entry("species", species_id)
	var now: String = Time.get_datetime_string_from_system()
	var jellycat: Dictionary = {
		"id": "jc_001",
		"species_id": species_id,
		"stage": 1,
		"hunger": int(species.get("default_hunger", 80)),
		"mood": int(species.get("default_mood", 70)),
		"cleanliness": int(species.get("default_cleanliness", 100)),
		"health": "healthy",
		"growth_exp": 0,
		"created_at": now,
		"last_fed_at": "",
		"last_touched_at": "",
		"last_cleaned_at": ""
	}
	GameState.set_jellycat(jellycat)
	RuntimeLogger.log_state("JellyCat created")
	SaveManager.save_game()
	return jellycat


static func _get_table_entry(table_name: String, key: String) -> Dictionary:
	var entry: Variant = GameApp.get_table(table_name).get(key, {})
	if entry is Dictionary:
		return entry
	return {}
