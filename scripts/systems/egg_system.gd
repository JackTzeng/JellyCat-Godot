extends Node

class_name EggSystem


static func ensure_starter_eggs() -> Array[Dictionary]:
	var added: int = GameState.ensure_starter_eggs()
	if added > 0:
		RuntimeLogger.log_state("Starter companion eggs added: %d" % added)
	return GameState.get_nursery_eggs()


static func select_starter_egg(egg_id: String) -> bool:
	if not GameState.set_active_egg_id(egg_id):
		RuntimeLogger.log_error("Cannot select missing egg: %s" % egg_id)
		return false
	RuntimeLogger.log_state("Active nursery egg selected: %s" % egg_id)
	return true
