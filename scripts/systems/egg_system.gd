extends Node

class_name EggSystem

static func create_starter_egg(species_id: String = "normal_jellycat") -> Dictionary:
	var required: int = int(GameApp.get_balance_value("egg_required_clicks", 10))
	return {
		"species_id": species_id,
		"source": "starter",
		"required_clicks": required,
		"current_clicks": 0,
		"is_hatched": false
	}


static func select_starter_egg() -> void:
	GameState.set_egg(create_starter_egg())
	RuntimeLogger.log_state("Starter egg created")
