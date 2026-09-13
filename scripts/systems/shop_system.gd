extends Node

class_name ShopSystem

static func can_buy(item_id: String, quantity: int = 1) -> bool:
	var total_price: int = get_total_price(item_id, quantity)
	if total_price < 0:
		return false
	return CurrencySystem.can_spend(total_price)


static func buy_item(item_id: String, quantity: int = 1) -> bool:
	var safe_quantity: int = max(quantity, 1)
	var item: Dictionary = _get_item(item_id)
	if item.is_empty():
		RuntimeLogger.log_error("Buy item failed: missing item %s" % item_id)
		return false
	if not bool(item.get("purchasable", false)):
		RuntimeLogger.log_error("Buy item failed: not purchasable %s" % item_id)
		return false
	var total_price: int = get_total_price(item_id, safe_quantity)
	if total_price < 0:
		RuntimeLogger.log_error("Buy item failed: invalid price %s" % item_id)
		return false
	if not CurrencySystem.can_spend(total_price):
		RuntimeLogger.log_error_throttled("not_enough_bubble_coin_%s" % item_id, "Not enough bubble_coin for %s" % item_id)
		return false
	RuntimeLogger.log_action("Buy item: %s x%d" % [item_id, safe_quantity])
	var old_count: int = GameState.get_inventory_count(item_id)
	if not CurrencySystem.spend_coin(total_price):
		RuntimeLogger.log_error_throttled("buy_failed_not_enough_bubble_coin", "Buy item failed: not enough bubble_coin")
		return false
	GameState.set_inventory_count(item_id, old_count + safe_quantity)
	var new_count: int = GameState.get_inventory_count(item_id)
	if old_count != new_count:
		RuntimeLogger.log_state("inventory %s changed: %d -> %d" % [item_id, old_count, new_count])
	RuntimeLogger.log_info("Buy item success")
	SaveManager.request_save()
	return true


static func get_item_price(item_id: String) -> int:
	var item: Dictionary = _get_item(item_id)
	if item.is_empty():
		return -1
	return int(item.get("price", -1))


static func get_total_price(item_id: String, quantity: int = 1) -> int:
	var price: int = get_item_price(item_id)
	if price < 0:
		return -1
	return price * max(quantity, 1)


static func _get_item(item_id: String) -> Dictionary:
	var item: Variant = GameApp.get_table("items").get(item_id, {})
	if item is Dictionary:
		return item as Dictionary
	return {}
