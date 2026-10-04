extends Node

class_name CoinDropSystem


static func can_spawn_coin_bubble(active_count: int) -> bool:
	if active_count >= int(GameApp.get_balance_value("max_coin_bubbles_on_screen", 10)):
		return false
	return not get_eligible_pet_ids().is_empty()


static func get_eligible_pet_ids() -> Array[String]:
	var result: Array[String] = []
	var mood_threshold: int = int(GameApp.get_balance_value("passive_coin_mood_threshold", 70))
	for pet_id in GameState.get_active_pet_ids():
		var pet: Dictionary = GameState.get_pet(pet_id)
		if str(pet.get("health", "healthy")) == "healthy" and int(pet.get("mood", 0)) >= mood_threshold:
			result.append(pet_id)
	return result


static func get_active_coin_bubble_count(container: Node) -> int:
	if container == null:
		return 0
	return container.get_child_count()


static func get_spawn_position(viewport_size: Vector2, source_position: Vector2) -> Vector2:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var offset: Vector2 = Vector2(rng.randf_range(-54.0, 54.0), rng.randf_range(-48.0, 12.0))
	var minimum: Vector2 = Vector2(72.0, 160.0)
	var maximum: Vector2 = Vector2(maxf(minimum.x, viewport_size.x - 72.0), maxf(minimum.y, viewport_size.y - 170.0))
	return Vector2(clampf(source_position.x + offset.x, minimum.x, maximum.x), clampf(source_position.y + offset.y, minimum.y, maximum.y))


static func reserve_coin(source_pet_id: String, value: int, position: Vector2) -> Dictionary:
	var lifetime: float = maxf(float(GameApp.get_balance_value("coin_bubble_auto_collect_seconds", 15.0)), 1.0)
	var drop: Dictionary = GameState.reserve_coin_drop(source_pet_id, value, position, Time.get_unix_time_from_system() + lifetime)
	if drop.is_empty():
		push_warning("Coin drop rejected for inactive source pet or invalid value: %s" % source_pet_id)
		return {}
	if not SaveManager.save_game():
		push_warning("Coin drop could not be saved; restoring its reservation.")
		GameState.cancel_coin_drop(str(drop.get("token_id", "")))
		SaveManager.save_game()
		return {}
	return drop


static func collect_coin(token_id: String, auto_collected: bool) -> Dictionary:
	var drop: Dictionary = GameState.resolve_coin_drop(token_id)
	if drop.is_empty():
		return {}
	if auto_collected:
		RuntimeLogger.log_info("Bubble coin auto-collected: +%d" % int(drop.get("value", 0)))
	else:
		RuntimeLogger.log_action("Bubble coin picked: +%d" % int(drop.get("value", 0)))
	if not SaveManager.save_game():
		push_warning("Coin transaction resolved in memory, but the immediate save failed.")
	return drop
