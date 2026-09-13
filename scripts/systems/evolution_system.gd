extends Node

class_name EvolutionSystem

static func can_evolve() -> bool:
	var jellycat: Dictionary = _get_jellycat()
	var next_stage: Dictionary = get_next_stage_data()
	if jellycat.is_empty() or next_stage.is_empty():
		if jellycat.is_empty():
			RuntimeLogger.log_error("No jellycat found")
		else:
			RuntimeLogger.log_info_throttled("already_max_stage", "Already max stage")
		return false
	return int(jellycat.get("growth_exp", 0)) >= int(next_stage.get("required_growth_exp", 0))


static func evolve() -> bool:
	var jellycat: Dictionary = _get_jellycat()
	if jellycat.is_empty():
		RuntimeLogger.log_error("No jellycat found")
		return false
	var next_stage: Dictionary = get_next_stage_data()
	if next_stage.is_empty():
		RuntimeLogger.log_info_throttled("already_max_stage", "Already max stage")
		return false
	if int(jellycat.get("growth_exp", 0)) < int(next_stage.get("required_growth_exp", 0)):
		RuntimeLogger.log_error_throttled("cannot_evolve_yet", "Cannot evolve yet")
		return false
	var old_stage: int = int(jellycat.get("stage", 1))
	jellycat["stage"] = old_stage + 1
	GameState.set_jellycat(jellycat)
	if old_stage != int(jellycat.get("stage", 1)):
		RuntimeLogger.log_state("stage changed: %d -> %d" % [old_stage, int(jellycat.get("stage", 1))])
		CurrencySystem.add_evolution_bonus(int(jellycat.get("stage", 1)))
	return true


static func get_current_stage_data() -> Dictionary:
	var jellycat: Dictionary = _get_jellycat()
	if jellycat.is_empty():
		return {}
	return _stage_data(str(jellycat.get("species_id", "normal_jellycat")), int(jellycat.get("stage", 1)))


static func get_next_stage_data() -> Dictionary:
	var jellycat: Dictionary = _get_jellycat()
	if jellycat.is_empty():
		return {}
	var stage: int = int(jellycat.get("stage", 1))
	var species: Dictionary = _get_table_entry("species", str(jellycat.get("species_id", "normal_jellycat")))
	if stage >= int(species.get("max_stage", 5)):
		return {}
	return _stage_data(str(jellycat.get("species_id", "normal_jellycat")), stage + 1)


static func _stage_data(species_id: String, stage: int) -> Dictionary:
	var species_evolution: Dictionary = _get_table_entry("evolution", species_id)
	for entry in species_evolution.get("stages", []):
		if int(entry.get("stage", 0)) == stage:
			return entry
	return {}


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
