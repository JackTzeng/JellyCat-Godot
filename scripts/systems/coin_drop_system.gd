extends Node

class_name CoinDropSystem

static func can_spawn_coin_bubble(active_count: int) -> bool:
	if active_count >= int(GameApp.get_balance_value("max_coin_bubbles_on_screen", 10)):
		return false
	var mood_threshold: int = int(GameApp.get_balance_value("passive_coin_mood_threshold", 70))
	for pet_id in GameState.get_active_pet_ids():
		var pet: Dictionary = GameState.get_pet(pet_id)
		if str(pet.get("health", "healthy")) == "healthy" and int(pet.get("mood", 0)) >= mood_threshold:
			return true
	return false


static func get_active_coin_bubble_count(container: Node) -> int:
	if container == null:
		return 0
	return container.get_child_count()


static func get_spawn_position(viewport_size: Vector2) -> Vector2:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var x_min: float = max(820.0, viewport_size.x * 0.49)
	var x_max: float = min(viewport_size.x - 360.0, viewport_size.x * 0.78)
	var y_min: float = max(340.0, viewport_size.y * 0.36)
	var y_max: float = min(540.0, viewport_size.y * 0.58)
	if x_max < x_min:
		x_min = 80.0
		x_max = max(80.0, viewport_size.x - 160.0)
	if y_max < y_min:
		y_min = 120.0
		y_max = max(120.0, viewport_size.y - 360.0)
	return Vector2(rng.randf_range(x_min, x_max), rng.randf_range(y_min, y_max))


static func collect_coin(value: int, auto_collected: bool) -> void:
	if value <= 0:
		return
	var old_coin: int = GameState.get_currency("bubble_coin")
	if auto_collected:
		RuntimeLogger.log_info("Bubble coin auto-collected: +%d" % value)
	else:
		RuntimeLogger.log_action("Bubble coin picked: +%d" % value)
	CurrencySystem.add_coin(value)
	if old_coin != GameState.get_currency("bubble_coin"):
		SaveManager.request_save()
