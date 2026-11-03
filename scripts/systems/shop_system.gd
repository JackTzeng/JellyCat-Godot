extends Node

class_name ShopSystem

static var _last_partner_purchase_frame: int = -1
static var _last_decor_purchase_frame: int = -1

static func can_buy(item_id: String, quantity: int = 1) -> bool:
	if item_id in ["food_basic", "cookie_basic"]:
		return false
	var item: Dictionary = _get_item(item_id)
	if str(item.get("type", "")) == "decor":
		if quantity != 1 or is_decor_owned(item_id) or GameState.get_owned_decor().size() >= int(GameApp.get_balance_value("decor_max_slots", 5)):
			return false
	var total_price: int = get_total_price(item_id, quantity)
	if total_price < 0:
		return false
	if _is_partner_egg(item_id) and is_partner_egg_at_limit():
		return false
	return CurrencySystem.can_spend(total_price)


static func buy_item(item_id: String, quantity: int = 1) -> bool:
	if item_id == "food_basic":
		RuntimeLogger.log_info("Basic food is unlimited")
		return false
	if item_id == "cookie_basic":
		RuntimeLogger.log_info("Cookies are not sold in the current test build")
		return false
	var safe_quantity: int = max(quantity, 1)
	var item: Dictionary = _get_item(item_id)
	if item.is_empty():
		RuntimeLogger.log_error("Buy item failed: missing item %s" % item_id)
		return false
	if not bool(item.get("purchasable", false)):
		RuntimeLogger.log_error("Buy item failed: not purchasable %s" % item_id)
		return false
	if _is_partner_egg(item_id):
		return _buy_partner_egg(item_id)
	if str(item.get("type", "")) == "decor":
		if safe_quantity != 1:
			return false
		return _buy_decor(item_id)
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
	if _is_partner_egg(item_id):
		var nursery: Dictionary = GameState.data.get("nursery", {}) as Dictionary
		var count: int = GameState.get_pet_ids().size() + (nursery.get("eggs", []) as Array).size()
		var start_count: int = maxi(3, int(GameApp.get_balance_value("partner_egg_price_start_count", 3)))
		var base: float = maxf(float(GameApp.get_balance_value("partner_egg_base_price", 100)), 0.0)
		var factor: float = maxf(float(GameApp.get_balance_value("partner_egg_price_factor", 1.5)), 1.0)
		var increment: int = maxi(1, int(GameApp.get_balance_value("partner_egg_price_round_to", 5)))
		var raw: float = base * pow(factor, maxi(count, start_count) - start_count)
		return int(ceili(raw / float(increment))) * increment
	var item: Dictionary = _get_item(item_id)
	if item.is_empty():
		return -1
	return int(item.get("price", -1))


static func is_decor_owned(item_id: String) -> bool:
	return GameState.is_decor_owned(item_id)


static func _buy_decor(item_id: String) -> bool:
	var current_frame: int = Engine.get_process_frames()
	if current_frame == _last_decor_purchase_frame or not can_buy(item_id):
		return false
	var price: int = get_item_price(item_id)
	if not GameState.purchase_decor(item_id, price):
		return false
	_last_decor_purchase_frame = current_frame
	SaveManager.save_game()
	RuntimeLogger.log_action("Buy decor: %s" % item_id)
	return true


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


static func _is_partner_egg(item_id: String) -> bool:
	return str(_get_item(item_id).get("type", "")) == "partner_egg"


static func is_partner_egg_at_limit() -> bool:
	var nursery: Dictionary = GameState.data.get("nursery", {}) as Dictionary
	var eggs: Array = nursery.get("eggs", []) as Array
	return GameState.get_pet_ids().size() + eggs.size() >= GameState.get_max_pets_technical()


static func _buy_partner_egg(item_id: String) -> bool:
	var current_frame: int = Engine.get_process_frames()
	if current_frame == _last_partner_purchase_frame:
		return false
	if is_partner_egg_at_limit():
		return false
	var item: Dictionary = _get_item(item_id)
	var total_price: int = get_total_price(item_id)
	if total_price < 0 or not CurrencySystem.can_spend(total_price):
		return false
	var egg_id: String = "egg_%03d" % (randi() % 900000 + 100000)
	while not GameState.get_nursery_egg(egg_id).is_empty():
		egg_id = "egg_%03d" % (randi() % 900000 + 100000)
	var egg: Dictionary = {"egg_id": egg_id, "pet_id": "", "species_id": str(item.get("species_id", "normal_jellycat")), "personality_id": "curious", "source": "shop_partner_egg", "required_clicks": maxi(1, int(GameApp.get_balance_value("egg_required_clicks", 10))), "current_clicks": 0, "is_hatched": false}
	if not GameState.purchase_partner_egg(egg, total_price):
		return false
	_last_partner_purchase_frame = current_frame
	SaveManager.save_game()
	RuntimeLogger.log_action("Buy partner egg: %s" % item_id)
	return true
