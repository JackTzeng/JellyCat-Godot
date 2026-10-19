extends Node

class_name FoodDropSystem


static func drop_food(position: Vector2) -> Dictionary:
	var lifetime: float = maxf(float(GameApp.get_balance_value("food_drop_lifetime_seconds", 45.0)), 1.0)
	var accelerated_lifetime: float = lifetime / float(TimeManager.get_time_scale())
	var drop: Dictionary = GameState.reserve_food_drop("food_basic", position, Time.get_unix_time_from_system() + accelerated_lifetime)
	if drop.is_empty():
		return {}
	if not SaveManager.save_game():
		GameState.resolve_food_drop(str(drop.get("token_id", "")))
		SaveManager.save_game()
		return {}
	return drop


static func rescale_expiration_deadlines(previous_scale: int, new_scale: int) -> bool:
	if previous_scale <= 0 or new_scale <= 0 or previous_scale == new_scale:
		return false
	var now: float = Time.get_unix_time_from_system()
	var changed: bool = false
	for drop in GameState.get_food_drops():
		var token_id: String = str(drop.get("token_id", ""))
		var expires_at: float = float(drop.get("expires_at", 0.0))
		if token_id.is_empty() or expires_at <= now:
			continue
		var remaining_gameplay_seconds: float = (expires_at - now) * float(previous_scale)
		var adjusted_expiration: float = now + remaining_gameplay_seconds / float(new_scale)
		changed = GameState.set_food_drop_expiration(token_id, adjusted_expiration) or changed
	if changed:
		SaveManager.request_save()
	return changed


static func consume_food(token_id: String, pet_id: String, coin_position: Vector2 = Vector2.ZERO) -> bool:
	var drop: Dictionary = _get_drop(token_id)
	if drop.is_empty() or float(drop.get("expires_at", 0.0)) <= Time.get_unix_time_from_system():
		return false
	var pet_data: Dictionary = CareSystem.build_fed_pet_data(pet_id, str(drop.get("item_id", "")))
	if pet_data.is_empty():
		return false
	var coin_value: int = int(GameApp.get_balance_value("meal_coin_base_value")) + int(pet_data.get("stage", 1))
	var coin_lifetime: float = maxf(float(GameApp.get_balance_value("coin_bubble_auto_collect_seconds")), 1.0)
	var coin_drop: Dictionary = GameState.resolve_food_drop_with_coin(
		token_id,
		pet_id,
		pet_data,
		coin_value,
		coin_position,
		Time.get_unix_time_from_system() + coin_lifetime
	)
	if coin_drop.is_empty():
		return false
	RuntimeLogger.log_info("coin from meal %s +%d by %s" % [token_id, coin_value, pet_id])
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
