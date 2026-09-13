extends Node

class_name DebugTools

static func add_hunger(amount: int = 10) -> void:
	var jellycat: Dictionary = _get_jellycat()
	if jellycat.is_empty():
		return
	jellycat["hunger"] = clamp(int(jellycat.get("hunger", 0)) + amount, 0, 100)
	GameState.set_jellycat(jellycat)


static func add_mood(amount: int = 10) -> void:
	var jellycat: Dictionary = _get_jellycat()
	if jellycat.is_empty():
		return
	jellycat["mood"] = clamp(int(jellycat.get("mood", 0)) + amount, 0, 100)
	GameState.set_jellycat(jellycat)


static func add_growth_exp(amount: int = 100) -> void:
	var jellycat: Dictionary = _get_jellycat()
	if jellycat.is_empty():
		return
	jellycat["growth_exp"] = int(jellycat.get("growth_exp", 0)) + amount
	GameState.set_jellycat(jellycat)


static func add_bubble_coin(amount: int = 100) -> void:
	CurrencySystem.add_coin(amount)


static func direct_evolve() -> void:
	var jellycat: Dictionary = _get_jellycat()
	var next_stage: Dictionary = EvolutionSystem.get_next_stage_data()
	if jellycat.is_empty() or next_stage.is_empty():
		return
	jellycat["growth_exp"] = max(int(jellycat.get("growth_exp", 0)), int(next_stage.get("required_growth_exp", 0)))
	GameState.set_jellycat(jellycat)
	EvolutionSystem.evolve()


static func reset_save() -> void:
	SaveManager.reset_save()
	SceneRouter.go_title()


static func simulate_days(days: int) -> void:
	CareSystem.simulate_days(float(days))


static func _get_jellycat() -> Dictionary:
	var jellycat: Variant = GameState.get_jellycat()
	if jellycat is Dictionary:
		return jellycat.duplicate(true)
	return {}
