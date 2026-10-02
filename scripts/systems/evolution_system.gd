extends Node

class_name EvolutionSystem

static func can_evolve(pet_id: String) -> bool:
	var pet: Dictionary = _get_pet(pet_id)
	var next_stage: Dictionary = get_next_stage_data(pet_id)
	if pet.is_empty() or next_stage.is_empty():
		if pet.is_empty():
			RuntimeLogger.log_error("No pet found for id: %s" % pet_id)
		else:
			RuntimeLogger.log_info_throttled("already_max_stage", "Already max stage")
		return false
	return int(pet.get("growth_exp", 0)) >= int(next_stage.get("required_growth_exp", 0))


static func evolve(pet_id: String) -> bool:
	var pet: Dictionary = _get_pet(pet_id)
	if pet.is_empty():
		RuntimeLogger.log_error("No pet found for id: %s" % pet_id)
		return false
	var next_stage: Dictionary = get_next_stage_data(pet_id)
	if next_stage.is_empty():
		RuntimeLogger.log_info_throttled("already_max_stage", "Already max stage")
		return false
	if int(pet.get("growth_exp", 0)) < int(next_stage.get("required_growth_exp", 0)):
		RuntimeLogger.log_error_throttled("cannot_evolve_yet", "Cannot evolve yet")
		return false
	var old_stage: int = int(pet.get("stage", 1))
	pet["stage"] = old_stage + 1
	if not GameState.set_pet(pet_id, pet):
		return false
	if old_stage != int(pet.get("stage", 1)):
		RuntimeLogger.log_state("%s stage changed: %d -> %d" % [pet_id, old_stage, int(pet.get("stage", 1))])
		CurrencySystem.add_evolution_bonus(int(pet.get("stage", 1)))
		if not SaveManager.save_game():
			push_warning("Evolution succeeded in memory, but the immediate save failed.")
	return true


static func get_current_stage_data(pet_id: String) -> Dictionary:
	var pet: Dictionary = _get_pet(pet_id)
	if pet.is_empty():
		return {}
	return _stage_data(str(pet.get("species_id", "normal_jellycat")), int(pet.get("stage", 1)))


static func get_next_stage_data(pet_id: String) -> Dictionary:
	var pet: Dictionary = _get_pet(pet_id)
	if pet.is_empty():
		return {}
	var stage: int = int(pet.get("stage", 1))
	var species: Dictionary = _get_table_entry("species", str(pet.get("species_id", "normal_jellycat")))
	if stage >= int(species.get("max_stage", 5)):
		return {}
	return _stage_data(str(pet.get("species_id", "normal_jellycat")), stage + 1)


static func _stage_data(species_id: String, stage: int) -> Dictionary:
	var species_evolution: Dictionary = _get_table_entry("evolution", species_id)
	for entry in species_evolution.get("stages", []):
		if int(entry.get("stage", 0)) == stage:
			return entry
	return {}


static func _get_pet(pet_id: String) -> Dictionary:
	return GameState.get_pet(pet_id)


static func _get_table_entry(table_name: String, key: String) -> Dictionary:
	var entry: Variant = GameApp.get_table(table_name).get(key, {})
	if entry is Dictionary:
		return entry
	return {}
