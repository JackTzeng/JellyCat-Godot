extends Node

class_name CurrencySystem

static func add_coin(amount: int, reason: String = "") -> void:
	if amount <= 0:
		return
	var old_coin: int = GameState.get_currency("bubble_coin")
	var new_coin: int = old_coin + amount
	GameState.set_currency("bubble_coin", new_coin)
	_log_coin_change(old_coin, new_coin)
	if not reason.is_empty():
		RuntimeLogger.log_info("%s +%d bubble_coin" % [reason, amount])


static func spend_coin(amount: int, reason: String = "") -> bool:
	if amount <= 0:
		return true
	var current: int = GameState.get_currency("bubble_coin")
	if current < amount:
		RuntimeLogger.log_error("Not enough bubble_coin")
		return false
	GameState.set_currency("bubble_coin", current - amount)
	_log_coin_change(current, current - amount)
	if not reason.is_empty():
		RuntimeLogger.log_info("%s -%d bubble_coin" % [reason, amount])
	return true


static func can_spend(amount: int) -> bool:
	return GameState.get_currency("bubble_coin") >= max(amount, 0)


static func process_passive_income(_delta: float) -> int:
	return 0


static func calculate_passive_income() -> int:
	var jellycat: Variant = GameState.get_jellycat()
	if not (jellycat is Dictionary):
		return 0
	var threshold: int = int(GameApp.get_balance_value("passive_coin_mood_threshold", 70))
	if int(jellycat.get("mood", 0)) < threshold:
		GameState.set_timestamp("last_passive_coin_at", Time.get_datetime_string_from_system(), false)
		return 0
	var interval: int = int(GameApp.get_balance_value("passive_coin_interval_seconds", 30))
	var last: String = GameState.get_timestamp("last_passive_coin_at")
	var seconds: float = TimeManager.seconds_since_datetime_string(last)
	var ticks: int = int(floor(seconds / float(max(interval, 1))))
	if ticks <= 0:
		return 0
	return ticks * int(GameApp.get_balance_value("passive_coin_amount", 1))


static func calculate_offline_income(elapsed_seconds: int) -> int:
	var jellycat: Variant = GameState.get_jellycat()
	if not (jellycat is Dictionary):
		return 0
	var threshold: int = int(GameApp.get_balance_value("passive_coin_mood_threshold", 70))
	if int(jellycat.get("mood", 0)) < threshold:
		return 0
	var capped_seconds: int = min(max(elapsed_seconds, 0), int(GameApp.get_balance_value("offline_coin_cap_seconds", 14400)))
	var interval: int = int(GameApp.get_balance_value("passive_coin_interval_seconds", 30))
	var ticks: int = int(floor(float(capped_seconds) / float(max(interval, 1))))
	return ticks * int(GameApp.get_balance_value("passive_coin_amount", 1))


static func apply_offline_income(elapsed_seconds: int) -> void:
	var amount: int = calculate_offline_income(elapsed_seconds)
	if amount <= 0:
		return
	add_coin(amount)
	var capped_seconds: int = min(max(elapsed_seconds, 0), int(GameApp.get_balance_value("offline_coin_cap_seconds", 14400)))
	RuntimeLogger.log_info("Offline income: +%d bubble_coin over %d seconds" % [amount, capped_seconds])


static func add_evolution_bonus(new_stage: int) -> void:
	var bonuses_value: Variant = GameApp.get_balance_value("evolution_coin_bonus", {})
	if not (bonuses_value is Dictionary):
		return
	var bonuses: Dictionary = bonuses_value as Dictionary
	var amount: int = int(bonuses.get(str(new_stage), 0))
	if amount <= 0:
		return
	add_coin(amount)
	RuntimeLogger.log_info("Evolution bonus +%d bubble_coin" % amount)


static func _log_coin_change(old_value: int, new_value: int) -> void:
	if old_value != new_value:
		RuntimeLogger.log_state("bubble_coin changed: %d -> %d" % [old_value, new_value])
