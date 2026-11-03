extends Node

class_name CoinDropSystem

const KIND_COIN: String = "coin"
const KIND_PEARL: String = "pearl"
const KIND_DIAMOND: String = "diamond"
const KINDS: Array[String] = [KIND_COIN, KIND_PEARL, KIND_DIAMOND]

# Injectable randomness for meal-coin rarity rolls (tests / reproducible regressions).
static var _rng: RandomNumberGenerator = null
static var _forced_roll: float = -1.0


static func seed_rng(seed_value: int) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value
	_forced_roll = -1.0


static func use_system_rng() -> void:
	_rng = null
	_forced_roll = -1.0


# Test hook: every roll returns this value in [0, 1] until cleared with use_system_rng()/seed_rng().
static func force_roll(roll: float) -> void:
	_forced_roll = clampf(roll, 0.0, 1.0)


static func next_roll() -> float:
	if _forced_roll >= 0.0:
		return _forced_roll
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	return _rng.randf()


static func normalize_kind(kind: Variant) -> String:
	var text: String = str(kind)
	return text if KINDS.has(text) else KIND_COIN


# One independent roll per meal: diamond band first, then pearl band, else a normal coin.
static func roll_meal_coin(normal_value: int, roll: float = -1.0) -> Dictionary:
	var value: float = next_roll() if roll < 0.0 else roll
	var diamond_chance: float = clampf(float(GameApp.get_balance_value("diamond_drop_chance", 0.0)), 0.0, 1.0)
	var pearl_chance: float = get_pearl_drop_chance()
	if value < diamond_chance:
		return {"kind": KIND_DIAMOND, "value": maxi(int(GameApp.get_balance_value("diamond_coin_value", 30)), 1)}
	if value < diamond_chance + pearl_chance:
		return {"kind": KIND_PEARL, "value": maxi(int(GameApp.get_balance_value("pearl_coin_value", 15)), 1)}
	return {"kind": KIND_COIN, "value": normal_value}


static func get_pearl_drop_chance() -> float:
	var chance: float = float(GameApp.get_balance_value("pearl_drop_chance", 0.0))
	for decor in GameState.get_owned_decor():
		var item: Variant = GameApp.get_table("items").get(str(decor.get("item_id", "")), {})
		if item is Dictionary:
			chance += float(((item as Dictionary).get("effect", {}) as Dictionary).get("pearl_chance_add", 0.0))
	return clampf(chance, 0.0, 1.0)


static func can_spawn_coin_bubble(active_count: int) -> bool:
	if active_count >= int(GameApp.get_balance_value("max_coin_bubbles_on_screen")):
		return false
	return not get_eligible_pet_ids().is_empty()


static func get_eligible_pet_ids() -> Array[String]:
	var result: Array[String] = []
	var mood_threshold: int = int(GameApp.get_balance_value("passive_coin_mood_threshold"))
	for pet_id in GameState.get_active_pet_ids():
		var pet: Dictionary = GameState.get_pet(pet_id)
		if str(pet.get("health", "healthy")) == "healthy" and int(pet.get("hunger", 0)) > 0 and int(pet.get("mood", 0)) >= mood_threshold:
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
	var lifetime: float = maxf(float(GameApp.get_balance_value("coin_bubble_auto_collect_seconds")), 1.0)
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
	var kind_label: String = "Bubble coin"
	match CoinDropSystem.normalize_kind(drop.get("kind", "coin")):
		CoinDropSystem.KIND_PEARL:
			kind_label = "Pearl"
		CoinDropSystem.KIND_DIAMOND:
			kind_label = "Diamond"
	if auto_collected:
		RuntimeLogger.log_info("%s auto-collected: +%d" % [kind_label, int(drop.get("value", 0))])
	else:
		RuntimeLogger.log_action("%s picked: +%d" % [kind_label, int(drop.get("value", 0))])
	if not SaveManager.save_game():
		push_warning("Coin transaction resolved in memory, but the immediate save failed.")
	return drop


static func get_meal_coin_drop(food_token_id: String) -> Dictionary:
	for drop in GameState.get_coin_drops():
		if str(drop.get("source", "")) == "meal" and str(drop.get("food_token_id", "")) == food_token_id:
			return drop
	return {}
