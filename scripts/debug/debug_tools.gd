extends Node

class_name DebugTools

static func add_hunger(pet_id: String, amount: int = 10) -> void:
	var pet: Dictionary = GameState.get_pet(pet_id)
	if pet.is_empty():
		return
	pet["hunger"] = clampi(int(pet.get("hunger", 0)) + amount, 0, 100)
	GameState.set_pet(pet_id, pet)


static func add_mood(pet_id: String, amount: int = 10) -> void:
	var pet: Dictionary = GameState.get_pet(pet_id)
	if pet.is_empty():
		return
	pet["mood"] = clampi(int(pet.get("mood", 0)) + amount, 0, 100)
	GameState.set_pet(pet_id, pet)


static func add_growth_exp(pet_id: String, amount: int = 100) -> void:
	var pet: Dictionary = GameState.get_pet(pet_id)
	if pet.is_empty():
		return
	pet["growth_exp"] = int(pet.get("growth_exp", 0)) + amount
	GameState.set_pet(pet_id, pet)


static func add_bubble_coin(amount: int = 100) -> void:
	CurrencySystem.add_coin(amount)


static func direct_evolve(pet_id: String) -> void:
	var pet: Dictionary = GameState.get_pet(pet_id)
	var next_stage: Dictionary = EvolutionSystem.get_next_stage_data(pet_id)
	if pet.is_empty() or next_stage.is_empty():
		return
	pet["growth_exp"] = max(int(pet.get("growth_exp", 0)), int(next_stage.get("required_growth_exp", 0)))
	GameState.set_pet(pet_id, pet)
	EvolutionSystem.evolve(pet_id)


static func reset_save() -> void:
	SaveManager.reset_save()
	SceneRouter.go_title()


static func simulate_days(days: int) -> void:
	CareSystem.simulate_days(float(days))

