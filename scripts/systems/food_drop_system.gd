extends Node

class_name FoodDropSystem


static func drop_food(position: Vector2) -> Dictionary:
	var lifetime: float = maxf(float(GameApp.get_balance_value("food_drop_lifetime_seconds", 45.0)), 1.0)
	var drop: Dictionary = GameState.reserve_food_drop("food_basic", position, Time.get_unix_time_from_system() + lifetime)
	if drop.is_empty():
		return {}
	if not SaveManager.save_game():
		GameState.resolve_food_drop(str(drop.get("token_id", "")))
		SaveManager.save_game()
		return {}
	return drop


static func consume_food(token_id: String, pet_id: String) -> bool:
	var drop: Dictionary = _get_drop(token_id)
	if drop.is_empty() or float(drop.get("expires_at", 0.0)) <= Time.get_unix_time_from_system():
		return false
	var pet_data: Dictionary = CareSystem.build_fed_pet_data(pet_id, str(drop.get("item_id", "")))
	if pet_data.is_empty() or not GameState.resolve_food_drop(token_id, pet_id, pet_data):
		return false
	if not SaveManager.save_game():
		push_warning("Food transaction resolved in memory, but the immediate save failed.")
	return true


static func expire_due_drops() -> int:
	var now: float = Time.get_unix_time_from_system()
	var expired: int = 0
	for drop in GameState.get_food_drops():
		if float(drop.get("expires_at", 0.0)) <= now and GameState.resolve_food_drop(str(drop.get("token_id", ""))):
			expired += 1
	if expired > 0:
		SaveManager.save_game()
	return expired


static func _get_drop(token_id: String) -> Dictionary:
	for drop in GameState.get_food_drops():
		if str(drop.get("token_id", "")) == token_id:
			return drop
	return {}
