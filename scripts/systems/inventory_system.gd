extends Node

class_name InventorySystem

static func add_item(item_id: String, amount: int) -> void:
	var old_count: int = GameState.get_inventory_count(item_id)
	var new_count: int = old_count + max(amount, 0)
	GameState.set_inventory_count(item_id, new_count)
	_log_item_count_change(item_id, old_count, new_count)


static func spend_item(item_id: String, amount: int) -> bool:
	var current: int = GameState.get_inventory_count(item_id)
	if current < amount:
		RuntimeLogger.log_error("Not enough item: %s" % item_id)
		return false
	var new_count: int = current - amount
	GameState.set_inventory_count(item_id, new_count)
	_log_item_count_change(item_id, current, new_count)
	return true


static func _log_item_count_change(item_id: String, old_count: int, new_count: int) -> void:
	if old_count != new_count:
		RuntimeLogger.log_state("%s count changed: %d -> %d" % [item_id, old_count, new_count])
