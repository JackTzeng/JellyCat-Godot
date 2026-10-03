extends Node

signal state_changed

const SAVE_VERSION: String = "0.2.0"
const SCHEMA_VERSION: int = 2
const STARTER_CAPACITY: int = 3
const MAX_PET_CAPACITY: int = 12
const STARTER_PERSONALITIES: Array[String] = ["curious", "affectionate", "sleepy"]

var data: Dictionary = {}


func _ready() -> void:
	reset_to_default()


func reset_to_default() -> void:
	var now: String = Time.get_datetime_string_from_system()
	data = {
		"save_version": SAVE_VERSION,
		"schema_version": SCHEMA_VERSION,
		"player": {"player_id": "local_player", "created_at": now},
		"pets": {},
		"aquarium": {
			"active_pet_ids": [],
			"selected_pet_id": "",
			"capacity": STARTER_CAPACITY,
			"cleanliness": 100,
			"facilities": [],
			"food_drops": [],
			"food_token_counter": 0
		},
		"nursery": {
			"eggs": [],
			"active_egg_id": "",
			"starter_pack_granted": false
		},
		"currency": {"bubble_coin": 20},
		"inventory": {"food_basic": 5, "cookie_basic": 3, "medicine_basic": 1},
		"daily_claim": {"last_free_food_date": ""},
		"unlocked_species": ["normal_jellycat"],
		"timestamps": {
			"last_saved_at": "",
			"last_opened_at": now,
			"last_passive_coin_at": now
		}
	}
	emit_signal("state_changed")


func set_data(next_data: Dictionary) -> bool:
	var prepared: Dictionary = prepare_data(next_data)
	if not bool(prepared.get("ok", false)):
		return false
	data = prepared["data"] as Dictionary
	emit_signal("state_changed")
	return true


func prepare_data(source: Dictionary) -> Dictionary:
	var next_data: Dictionary = source.duplicate(true)
	var raw_schema: Variant = next_data.get("schema_version", 1)
	if typeof(raw_schema) != TYPE_INT and typeof(raw_schema) != TYPE_FLOAT:
		return {"ok": false, "reason": "invalid_schema_version", "data": {}}
	var schema_number: float = float(raw_schema)
	if not is_finite(schema_number) or schema_number < 1.0 or schema_number > float(SCHEMA_VERSION) or floor(schema_number) != schema_number:
		return {"ok": false, "reason": "unsupported_schema", "data": {}}
	var old_schema: int = int(schema_number)
	if old_schema > SCHEMA_VERSION or old_schema < 1:
		return {"ok": false, "reason": "unsupported_schema", "data": {}}
	var expected_root_types: Dictionary = {
		"player": TYPE_DICTIONARY,
		"pets": TYPE_DICTIONARY,
		"aquarium": TYPE_DICTIONARY,
		"nursery": TYPE_DICTIONARY,
		"currency": TYPE_DICTIONARY,
		"inventory": TYPE_DICTIONARY,
		"care_stats": TYPE_DICTIONARY,
		"daily_claim": TYPE_DICTIONARY,
		"unlocked_species": TYPE_ARRAY,
		"timestamps": TYPE_DICTIONARY
	}
	for key in expected_root_types.keys():
		if next_data.has(key) and typeof(next_data[key]) != int(expected_root_types[key]):
			return {"ok": false, "reason": "invalid_%s" % str(key), "data": {}}
	if next_data.has("pets"):
		var source_pets: Dictionary = next_data["pets"] as Dictionary
		for raw_pet_id in source_pets.keys():
			if typeof(raw_pet_id) != TYPE_STRING or not (source_pets[raw_pet_id] is Dictionary):
				return {"ok": false, "reason": "invalid_pet_record", "data": {}}
			var source_pet: Dictionary = source_pets[raw_pet_id] as Dictionary
			if source_pet.has("care_stats") and not (source_pet["care_stats"] is Dictionary):
				return {"ok": false, "reason": "invalid_pet_care_stats", "data": {}}
			if source_pet.has("visual_params") and not (source_pet["visual_params"] is Dictionary):
				return {"ok": false, "reason": "invalid_pet_visual_params", "data": {}}
	if next_data.has("aquarium"):
		var source_aquarium: Dictionary = next_data["aquarium"] as Dictionary
		if source_aquarium.has("active_pet_ids") and not (source_aquarium["active_pet_ids"] is Array):
			return {"ok": false, "reason": "invalid_active_pet_ids", "data": {}}
		if source_aquarium.has("facilities") and not (source_aquarium["facilities"] is Array):
			return {"ok": false, "reason": "invalid_facilities", "data": {}}
		if source_aquarium.has("food_drops") and not (source_aquarium["food_drops"] is Array):
			return {"ok": false, "reason": "invalid_food_drops", "data": {}}
	if next_data.has("nursery"):
		var source_nursery: Dictionary = next_data["nursery"] as Dictionary
		if source_nursery.has("eggs") and not (source_nursery["eggs"] is Array):
			return {"ok": false, "reason": "invalid_nursery_eggs", "data": {}}
	var migrated: bool = old_schema < SCHEMA_VERSION
	if old_schema < 2:
		var legacy_pets: Dictionary = next_data.get("pets", {}).duplicate(true) as Dictionary
		var old_pet: Variant = next_data.get("jellycat")
		if old_pet is Dictionary:
			var pet_record: Dictionary = (old_pet as Dictionary).duplicate(true)
			var legacy_id: String = str(pet_record.get("pet_id", pet_record.get("id", "jc_001")))
			if legacy_id.is_empty():
				legacy_id = "jc_001"
			if legacy_id != legacy_id.strip_edges():
				return {"ok": false, "reason": "invalid_legacy_pet_id", "data": {}}
			pet_record["pet_id"] = legacy_id
			pet_record["personality_id"] = str(pet_record.get("personality_id", "curious"))
			var source_care_stats: Variant = next_data.get("care_stats", pet_record.get("care_stats", _default_care_stats()))
			pet_record["care_stats"] = (source_care_stats as Dictionary).duplicate(true)
			if legacy_pets.has(legacy_id):
				var existing_pet: Dictionary = legacy_pets[legacy_id] as Dictionary
				for key in pet_record.keys():
					if not existing_pet.has(key):
						existing_pet[key] = pet_record[key]
				legacy_pets[legacy_id] = existing_pet
			else:
				legacy_pets[legacy_id] = pet_record
		next_data["pets"] = legacy_pets
		var old_cleanliness: int = 100
		if old_pet is Dictionary:
			old_cleanliness = int((old_pet as Dictionary).get("cleanliness", 100))
		var aquarium: Dictionary = next_data.get("aquarium", {}) as Dictionary
		if not aquarium.has("cleanliness"):
			aquarium["cleanliness"] = old_cleanliness
		var old_egg: Variant = next_data.get("egg")
		var nursery: Dictionary = next_data.get("nursery", {}) as Dictionary
		var eggs: Array = nursery.get("eggs", []) as Array
		if old_egg is Dictionary and not bool((old_egg as Dictionary).get("is_hatched", false)):
			var preserved_egg: Dictionary = (old_egg as Dictionary).duplicate(true)
			preserved_egg["egg_id"] = str(preserved_egg.get("egg_id", "egg_001"))
			preserved_egg["is_hatched"] = false
			eggs.append(preserved_egg)
		nursery["eggs"] = eggs
		next_data["aquarium"] = aquarium
		next_data["nursery"] = nursery
		next_data.erase("jellycat")
		next_data.erase("egg")
		next_data.erase("care_stats")
		next_data["schema_version"] = 2
		next_data["save_version"] = SAVE_VERSION
	_ensure_root_defaults(next_data)
	var pets_value: Variant = next_data.get("pets", {})
	if not (pets_value is Dictionary):
		return {"ok": false, "reason": "invalid_pets", "data": {}}
	var pets: Dictionary = (pets_value as Dictionary).duplicate(true)
	var normalized_pets: Dictionary = {}
	for raw_id in pets.keys():
		var pet_id: String = str(raw_id)
		var raw_pet: Variant = pets[raw_id]
		if pet_id.is_empty() or pet_id != pet_id.strip_edges() or not (raw_pet is Dictionary):
			return {"ok": false, "reason": "invalid_pet_record", "data": {}}
		if normalized_pets.has(pet_id):
			return {"ok": false, "reason": "duplicate_pet_id", "data": {}}
		var pet: Dictionary = (raw_pet as Dictionary).duplicate(true)
		pet["pet_id"] = pet_id
		var personality_id: String = str(pet.get("personality_id", "curious"))
		var personality_table: Dictionary = GameApp.get_table("personalities")
		if personality_id.is_empty() or not personality_table.has(personality_id):
			pet["personality_id"] = "curious"
		normalized_pets[pet_id] = _normalize_pet(pet_id, pet)
	next_data["pets"] = normalized_pets
	var aquarium: Dictionary = next_data["aquarium"] as Dictionary
	var active_ids: Array[String] = []
	var requested_ids: Variant = aquarium.get("active_pet_ids", [])
	if requested_ids is Array:
		for raw_id in requested_ids as Array:
			var pet_id: String = str(raw_id)
			if normalized_pets.has(pet_id) and not active_ids.has(pet_id) and active_ids.size() < int(aquarium.get("capacity", STARTER_CAPACITY)):
				active_ids.append(pet_id)
	if active_ids.is_empty():
		for pet_id in normalized_pets.keys():
			if active_ids.size() >= int(aquarium.get("capacity", STARTER_CAPACITY)):
				break
			active_ids.append(str(pet_id))
	aquarium["active_pet_ids"] = active_ids
	aquarium["capacity"] = clampi(int(aquarium.get("capacity", STARTER_CAPACITY)), 1, MAX_PET_CAPACITY)
	aquarium["cleanliness"] = clampi(int(aquarium.get("cleanliness", 100)), 0, 100)
	var food_drops: Array[Dictionary] = []
	var seen_food_tokens: Dictionary = {}
	var max_food_token: int = max(int(aquarium.get("food_token_counter", 0)), 0)
	for raw_drop in aquarium.get("food_drops", []) as Array:
		if not (raw_drop is Dictionary):
			return {"ok": false, "reason": "invalid_food_drop_record", "data": {}}
		var drop: Dictionary = (raw_drop as Dictionary).duplicate(true)
		var token_id: String = str(drop.get("token_id", ""))
		var item_id: String = str(drop.get("item_id", ""))
		var raw_x: Variant = drop.get("x", null)
		var raw_y: Variant = drop.get("y", null)
		var raw_expiry: Variant = drop.get("expires_at", null)
		if token_id.is_empty() or token_id != token_id.strip_edges() or seen_food_tokens.has(token_id):
			return {"ok": false, "reason": "invalid_food_token_id", "data": {}}
		if item_id != "food_basic" or not GameApp.get_table("items").has(item_id):
			return {"ok": false, "reason": "invalid_food_drop_item", "data": {}}
		if typeof(raw_x) not in [TYPE_INT, TYPE_FLOAT] or typeof(raw_y) not in [TYPE_INT, TYPE_FLOAT] or typeof(raw_expiry) not in [TYPE_INT, TYPE_FLOAT]:
			return {"ok": false, "reason": "invalid_food_drop_position", "data": {}}
		if not is_finite(float(raw_x)) or not is_finite(float(raw_y)) or not is_finite(float(raw_expiry)) or float(raw_expiry) <= 0.0:
			return {"ok": false, "reason": "invalid_food_drop_position", "data": {}}
		drop["token_id"] = token_id
		drop["item_id"] = item_id
		drop["x"] = float(raw_x)
		drop["y"] = float(raw_y)
		drop["expires_at"] = float(raw_expiry)
		seen_food_tokens[token_id] = true
		var token_number: String = token_id.trim_prefix("food_")
		if token_number.is_valid_int():
			max_food_token = max(max_food_token, int(token_number))
		food_drops.append(drop)
	aquarium["food_drops"] = food_drops
	aquarium["food_token_counter"] = max_food_token
	var selected_id: String = str(aquarium.get("selected_pet_id", ""))
	if not active_ids.has(selected_id):
		aquarium["selected_pet_id"] = active_ids[0] if not active_ids.is_empty() else ""
	next_data["aquarium"] = aquarium
	var nursery: Dictionary = next_data["nursery"] as Dictionary
	var nursery_eggs: Array = nursery.get("eggs", []) as Array
	var seen_egg_ids: Dictionary = {}
	var clean_eggs: Array[Dictionary] = []
	for raw_egg in nursery_eggs:
		if not (raw_egg is Dictionary):
			return {"ok": false, "reason": "invalid_egg_record", "data": {}}
		var egg: Dictionary = (raw_egg as Dictionary).duplicate(true)
		var egg_id: String = str(egg.get("egg_id", ""))
		if egg_id.is_empty() or egg_id != egg_id.strip_edges() or seen_egg_ids.has(egg_id):
			return {"ok": false, "reason": "invalid_egg_id", "data": {}}
		egg["egg_id"] = egg_id
		egg["is_hatched"] = false
		egg["current_clicks"] = max(int(egg.get("current_clicks", 0)), 0)
		egg["required_clicks"] = max(int(egg.get("required_clicks", 10)), 1)
		seen_egg_ids[egg_id] = true
		clean_eggs.append(egg)
	nursery["eggs"] = clean_eggs
	var active_egg_id: String = str(nursery.get("active_egg_id", ""))
	if not seen_egg_ids.has(active_egg_id):
		nursery["active_egg_id"] = str(clean_eggs[0].get("egg_id", "")) if not clean_eggs.is_empty() else ""
	nursery["starter_pack_granted"] = bool(nursery.get("starter_pack_granted", false))
	if migrated and not normalized_pets.is_empty() and not bool(nursery["starter_pack_granted"]):
		_grant_missing_starter_eggs(nursery, normalized_pets.size(), int(aquarium.get("capacity", STARTER_CAPACITY)), normalized_pets)
		nursery["starter_pack_granted"] = true
	next_data["nursery"] = nursery
	return {"ok": true, "migrated": migrated, "data": next_data}


func mark_changed(auto_save: bool = true) -> void:
	emit_signal("state_changed")
	if auto_save and SaveManager != null:
		SaveManager.request_save()


func get_pet_ids() -> Array[String]:
	var ids: Array[String] = []
	for pet_id in data.get("pets", {}).keys():
		ids.append(str(pet_id))
	ids.sort()
	return ids


func get_active_pet_ids() -> Array[String]:
	var ids: Array[String] = []
	var aquarium: Dictionary = data.get("aquarium", {}) as Dictionary
	for raw_id in aquarium.get("active_pet_ids", []) as Array:
		var pet_id: String = str(raw_id)
		if data.get("pets", {}).has(pet_id):
			ids.append(pet_id)
	return ids


func get_selected_pet_id() -> String:
	var aquarium: Dictionary = data.get("aquarium", {}) as Dictionary
	var selected_id: String = str(aquarium.get("selected_pet_id", ""))
	if data.get("pets", {}).has(selected_id):
		return selected_id
	var ids: Array[String] = get_active_pet_ids()
	return ids[0] if not ids.is_empty() else ""


func set_selected_pet_id(pet_id: String) -> bool:
	if not data.get("pets", {}).has(pet_id) or not get_active_pet_ids().has(pet_id):
		return false
	var aquarium: Dictionary = data["aquarium"] as Dictionary
	aquarium["selected_pet_id"] = pet_id
	mark_changed()
	return true


func get_pet(pet_id: String) -> Dictionary:
	var pets: Dictionary = data.get("pets", {}) as Dictionary
	var pet: Variant = pets.get(pet_id, {})
	return (pet as Dictionary).duplicate(true) if pet is Dictionary else {}


func add_pet(pet_data: Dictionary) -> bool:
	var pet_id: String = str(pet_data.get("pet_id", ""))
	var pets: Dictionary = data.get("pets", {}) as Dictionary
	var aquarium: Dictionary = data.get("aquarium", {}) as Dictionary
	var personality_id: String = str(pet_data.get("personality_id", "curious"))
	if pet_id.is_empty() or pet_id != pet_id.strip_edges() or pets.has(pet_id) or pets.size() >= int(aquarium.get("capacity", STARTER_CAPACITY)):
		return false
	if not GameApp.get_table("personalities").has(personality_id):
		return false
	var pet: Dictionary = pet_data.duplicate(true)
	pet["pet_id"] = pet_id
	pets[pet_id] = _normalize_pet(pet_id, pet)
	var active_ids: Array[String] = get_active_pet_ids()
	active_ids.append(pet_id)
	aquarium["active_pet_ids"] = active_ids
	if str(aquarium.get("selected_pet_id", "")).is_empty():
		aquarium["selected_pet_id"] = pet_id
	mark_changed()
	return true


func set_pet(pet_id: String, pet_data: Dictionary) -> bool:
	var pets: Dictionary = data.get("pets", {}) as Dictionary
	if pet_id.is_empty() or pet_id != pet_id.strip_edges() or not pets.has(pet_id):
		return false
	var pet: Dictionary = pet_data.duplicate(true)
	pet["pet_id"] = pet_id
	pet["personality_id"] = str(pets[pet_id].get("personality_id", pet.get("personality_id", "curious")))
	pets[pet_id] = _normalize_pet(pet_id, pet)
	mark_changed()
	return true


func set_pet_and_care_stats(pet_id: String, pet_data: Dictionary, care_stats: Dictionary) -> bool:
	var pet: Dictionary = pet_data.duplicate(true)
	pet["care_stats"] = care_stats.duplicate(true)
	return set_pet(pet_id, pet)


func rename_pet(pet_id: String, nickname: String) -> bool:
	var pet: Dictionary = get_pet(pet_id)
	var clean_name: String = nickname.strip_edges()
	if pet.is_empty() or clean_name.is_empty() or clean_name.length() > 18:
		return false
	pet["nickname"] = clean_name
	return set_pet(pet_id, pet)


func get_aquarium() -> Dictionary:
	return (data.get("aquarium", {}) as Dictionary).duplicate(true)


func set_aquarium_cleanliness(value: int) -> void:
	var aquarium: Dictionary = data["aquarium"] as Dictionary
	aquarium["cleanliness"] = clampi(value, 0, 100)
	mark_changed()


func get_food_drops() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for drop in (data.get("aquarium", {}) as Dictionary).get("food_drops", []) as Array:
		if drop is Dictionary:
			result.append((drop as Dictionary).duplicate(true))
	return result


func reserve_food_drop(item_id: String, position: Vector2, expires_at: float) -> Dictionary:
	if item_id != "food_basic" or GameState.get_inventory_count(item_id) <= 0:
		return {}
	var aquarium: Dictionary = data["aquarium"] as Dictionary
	var drops: Array = aquarium.get("food_drops", []) as Array
	var token_number: int = max(int(aquarium.get("food_token_counter", 0)), 0) + 1
	var token_id: String = "food_%08d" % token_number
	while _has_food_token(drops, token_id):
		token_number += 1
		token_id = "food_%08d" % token_number
	aquarium["food_token_counter"] = token_number
	drops.append({
		"token_id": token_id,
		"item_id": item_id,
		"x": position.x,
		"y": position.y,
		"expires_at": maxf(expires_at, Time.get_unix_time_from_system() + 1.0)
	})
	aquarium["food_drops"] = drops
	var inventory: Dictionary = data["inventory"] as Dictionary
	inventory[item_id] = max(0, int(inventory.get(item_id, 0)) - 1)
	mark_changed()
	return drops[-1].duplicate(true)


func resolve_food_drop(token_id: String, pet_id: String = "", pet_data: Dictionary = {}) -> bool:
	var aquarium: Dictionary = data["aquarium"] as Dictionary
	var drops: Array = aquarium.get("food_drops", []) as Array
	var drop_index: int = -1
	var drop: Dictionary = {}
	for index in range(drops.size()):
		if drops[index] is Dictionary and str((drops[index] as Dictionary).get("token_id", "")) == token_id:
			drop_index = index
			drop = (drops[index] as Dictionary).duplicate(true)
			break
	if drop_index < 0:
		return false
	if pet_data.is_empty():
		var item_id: String = str(drop.get("item_id", ""))
		var inventory: Dictionary = data["inventory"] as Dictionary
		inventory[item_id] = int(inventory.get(item_id, 0)) + 1
	else:
		var pets: Dictionary = data["pets"] as Dictionary
		if pet_id.is_empty() or not pets.has(pet_id) or not get_active_pet_ids().has(pet_id) or str(pet_data.get("pet_id", "")) != pet_id:
			return false
		pets[pet_id] = _normalize_pet(pet_id, pet_data)
	drops.remove_at(drop_index)
	aquarium["food_drops"] = drops
	mark_changed()
	return true


func _has_food_token(drops: Array, token_id: String) -> bool:
	for drop in drops:
		if drop is Dictionary and str((drop as Dictionary).get("token_id", "")) == token_id:
			return true
	return false


func get_nursery_eggs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for egg in (data.get("nursery", {}) as Dictionary).get("eggs", []) as Array:
		if egg is Dictionary:
			result.append((egg as Dictionary).duplicate(true))
	return result


func get_nursery_egg(egg_id: String) -> Dictionary:
	for egg in get_nursery_eggs():
		if str(egg.get("egg_id", "")) == egg_id:
			return egg
	return {}


func get_active_egg_id() -> String:
	var nursery: Dictionary = data.get("nursery", {}) as Dictionary
	return str(nursery.get("active_egg_id", ""))


func set_active_egg_id(egg_id: String) -> bool:
	if get_nursery_egg(egg_id).is_empty():
		return false
	var nursery: Dictionary = data["nursery"] as Dictionary
	nursery["active_egg_id"] = egg_id
	mark_changed()
	return true


func add_nursery_egg(egg_data: Dictionary) -> bool:
	var egg_id: String = str(egg_data.get("egg_id", ""))
	if egg_id.is_empty() or egg_id != egg_id.strip_edges() or not get_nursery_egg(egg_id).is_empty():
		return false
	var nursery: Dictionary = data["nursery"] as Dictionary
	var eggs: Array = nursery.get("eggs", []) as Array
	eggs.append(egg_data.duplicate(true))
	nursery["eggs"] = eggs
	if str(nursery.get("active_egg_id", "")).is_empty():
		nursery["active_egg_id"] = egg_id
	mark_changed()
	return true


func update_nursery_egg(egg_id: String, egg_data: Dictionary) -> bool:
	var nursery: Dictionary = data["nursery"] as Dictionary
	var eggs: Array = nursery.get("eggs", []) as Array
	for index in range(eggs.size()):
		if str((eggs[index] as Dictionary).get("egg_id", "")) == egg_id:
			var next_egg: Dictionary = egg_data.duplicate(true)
			next_egg["egg_id"] = egg_id
			eggs[index] = next_egg
			nursery["eggs"] = eggs
			mark_changed()
			return true
	return false


func hatch_egg(egg_id: String, pet_data: Dictionary) -> bool:
	if egg_id.is_empty() or egg_id != egg_id.strip_edges():
		return false
	var nursery: Dictionary = data["nursery"] as Dictionary
	var eggs: Array = nursery.get("eggs", []) as Array
	var egg_index: int = -1
	var egg: Dictionary = {}
	for index in range(eggs.size()):
		var candidate: Variant = eggs[index]
		if candidate is Dictionary and str((candidate as Dictionary).get("egg_id", "")) == egg_id:
			egg_index = index
			egg = (candidate as Dictionary).duplicate(true)
			break
	if egg_index < 0 or int(egg.get("current_clicks", 0)) < int(egg.get("required_clicks", 10)):
		return false
	var pet_id: String = str(pet_data.get("pet_id", ""))
	if pet_id.is_empty() or pet_id != pet_id.strip_edges():
		return false
	var registered_pet_id: String = str(egg.get("pet_id", ""))
	if not registered_pet_id.is_empty() and registered_pet_id != pet_id:
		return false
	var pets: Dictionary = data["pets"] as Dictionary
	var aquarium: Dictionary = data["aquarium"] as Dictionary
	if pets.has(pet_id) or pets.size() >= int(aquarium.get("capacity", STARTER_CAPACITY)):
		return false
	var personality_id: String = str(pet_data.get("personality_id", "curious"))
	var egg_personality_id: String = str(egg.get("personality_id", ""))
	if not egg_personality_id.is_empty() and personality_id != egg_personality_id:
		return false
	if not GameApp.get_table("personalities").has(personality_id):
		return false
	if str(pet_data.get("species_id", "")) != str(egg.get("species_id", "normal_jellycat")):
		return false
	var active_ids: Array[String] = get_active_pet_ids()
	if active_ids.size() >= int(aquarium.get("capacity", STARTER_CAPACITY)):
		return false
	var normalized_pet: Dictionary = pet_data.duplicate(true)
	normalized_pet["pet_id"] = pet_id
	pets[pet_id] = _normalize_pet(pet_id, normalized_pet)
	active_ids.append(pet_id)
	aquarium["active_pet_ids"] = active_ids
	var selected_id: String = str(aquarium.get("selected_pet_id", ""))
	if not active_ids.has(selected_id):
		aquarium["selected_pet_id"] = pet_id
	eggs.remove_at(egg_index)
	nursery["eggs"] = eggs
	if str(nursery.get("active_egg_id", "")) == egg_id:
		nursery["active_egg_id"] = str(eggs[0].get("egg_id", "")) if not eggs.is_empty() else ""
	mark_changed()
	return true


func remove_nursery_egg(egg_id: String) -> bool:
	var nursery: Dictionary = data["nursery"] as Dictionary
	var eggs: Array = nursery.get("eggs", []) as Array
	var found: bool = false
	for index in range(eggs.size() - 1, -1, -1):
		if str((eggs[index] as Dictionary).get("egg_id", "")) == egg_id:
			eggs.remove_at(index)
			found = true
	if not found:
		return false
	nursery["eggs"] = eggs
	if str(nursery.get("active_egg_id", "")) == egg_id:
		nursery["active_egg_id"] = str(eggs[0].get("egg_id", "")) if not eggs.is_empty() else ""
	mark_changed()
	return true


func ensure_starter_eggs() -> int:
	var nursery: Dictionary = data["nursery"] as Dictionary
	if bool(nursery.get("starter_pack_granted", false)):
		return 0
	var capacity: int = int((data.get("aquarium", {}) as Dictionary).get("capacity", STARTER_CAPACITY))
	var missing: int = max(0, min(STARTER_CAPACITY, capacity) - get_pet_ids().size() - get_nursery_eggs().size())
	for _index in range(missing):
		var egg_id: String = _next_egg_id()
		var pet_id: String = _next_pet_id()
		var personality_index: int = (get_pet_ids().size() + get_nursery_eggs().size()) % STARTER_PERSONALITIES.size()
		var egg: Dictionary = {
			"egg_id": egg_id,
			"pet_id": pet_id,
			"species_id": "normal_jellycat",
			"personality_id": STARTER_PERSONALITIES[personality_index],
			"source": "starter_companion",
			"required_clicks": 10,
			"current_clicks": 0,
			"is_hatched": false
		}
		if not add_nursery_egg(egg):
			return 0
	nursery = data["nursery"] as Dictionary
	nursery["starter_pack_granted"] = true
	mark_changed()
	return missing


func get_currency(currency_id: String) -> int:
	var currency: Dictionary = _get_or_create_dictionary("currency")
	return int(currency.get(currency_id, 0))


func set_currency(currency_id: String, amount: int) -> void:
	var currency: Dictionary = _get_or_create_dictionary("currency")
	currency[currency_id] = max(amount, 0)
	mark_changed()


func get_inventory_count(item_id: String) -> int:
	var inventory: Dictionary = _get_or_create_dictionary("inventory")
	return int(inventory.get(item_id, 0))


func set_inventory_count(item_id: String, count: int) -> void:
	var inventory: Dictionary = _get_or_create_dictionary("inventory")
	inventory[item_id] = max(count, 0)
	mark_changed()


func get_daily_claim() -> Dictionary:
	return _get_or_create_dictionary("daily_claim").duplicate(true)


func set_daily_claim(daily_claim: Dictionary) -> void:
	data["daily_claim"] = daily_claim.duplicate(true)
	mark_changed()


func get_timestamp(key: String) -> String:
	var timestamps: Dictionary = _get_or_create_dictionary("timestamps")
	return str(timestamps.get(key, ""))


func set_timestamp(key: String, value: String, auto_save: bool = true) -> void:
	var timestamps: Dictionary = _get_or_create_dictionary("timestamps")
	timestamps[key] = value
	mark_changed(auto_save)


func has_unhatched_egg() -> bool:
	return not get_nursery_eggs().is_empty()


func has_jellycat() -> bool:
	return not get_pet_ids().is_empty()


func get_egg() -> Variant:
	# Read-only transition adapter for older UI/tests. All egg writes require an egg_id.
	return get_nursery_egg(get_active_egg_id())


func get_jellycat() -> Variant:
	# Read-only transition adapter. New code must bind and read an explicit pet_id.
	return get_pet(get_selected_pet_id())


func get_care_stats() -> Dictionary:
	var pet: Dictionary = get_pet(get_selected_pet_id())
	return (pet.get("care_stats", {}) as Dictionary).duplicate(true)


func get_current_care_stats(pet_id: String) -> Dictionary:
	var pet: Dictionary = get_pet(pet_id)
	return (pet.get("care_stats", {}) as Dictionary).duplicate(true)


func to_save_dict() -> Dictionary:
	return data.duplicate(true)


func _ensure_root_defaults(target: Dictionary) -> void:
	target["save_version"] = SAVE_VERSION
	target["schema_version"] = SCHEMA_VERSION
	if not target.get("player") is Dictionary:
		target["player"] = {"player_id": "local_player", "created_at": Time.get_datetime_string_from_system()}
	if not target.get("pets") is Dictionary:
		target["pets"] = {}
	if not target.get("aquarium") is Dictionary:
		target["aquarium"] = {}
	var aquarium: Dictionary = target["aquarium"] as Dictionary
	if not aquarium.has("active_pet_ids"):
		aquarium["active_pet_ids"] = []
	if not aquarium.has("selected_pet_id"):
		aquarium["selected_pet_id"] = ""
	if not aquarium.has("capacity"):
		aquarium["capacity"] = STARTER_CAPACITY
	if not aquarium.has("cleanliness"):
		aquarium["cleanliness"] = 100
	if not aquarium.has("facilities"):
		aquarium["facilities"] = []
	if not aquarium.has("food_drops"):
		aquarium["food_drops"] = []
	if not aquarium.has("food_token_counter"):
		aquarium["food_token_counter"] = 0
	if not target.get("nursery") is Dictionary:
		target["nursery"] = {}
	var nursery: Dictionary = target["nursery"] as Dictionary
	if not nursery.get("eggs") is Array:
		nursery["eggs"] = []
	if not nursery.has("active_egg_id"):
		nursery["active_egg_id"] = ""
	if not nursery.has("starter_pack_granted"):
		nursery["starter_pack_granted"] = false
	if not target.get("currency") is Dictionary:
		target["currency"] = {"bubble_coin": 20}
	if not target.get("inventory") is Dictionary:
		target["inventory"] = {"food_basic": 5, "cookie_basic": 3, "medicine_basic": 1}
	if not target.get("daily_claim") is Dictionary:
		target["daily_claim"] = {"last_free_food_date": ""}
	if not target.has("unlocked_species"):
		target["unlocked_species"] = ["normal_jellycat"]
	if not target.get("timestamps") is Dictionary:
		target["timestamps"] = {}
	var now: String = Time.get_datetime_string_from_system()
	var timestamps: Dictionary = target["timestamps"] as Dictionary
	if not timestamps.has("last_saved_at"):
		timestamps["last_saved_at"] = ""
	if not timestamps.has("last_opened_at"):
		timestamps["last_opened_at"] = now
	if not timestamps.has("last_passive_coin_at"):
		timestamps["last_passive_coin_at"] = now


func _normalize_pet(pet_id: String, source: Dictionary) -> Dictionary:
	var pet: Dictionary = source.duplicate(true)
	var species_id: String = str(pet.get("species_id", "normal_jellycat"))
	var species: Dictionary = GameApp.get_table("species").get(species_id, {}) as Dictionary
	pet["pet_id"] = pet_id
	pet["species_id"] = species_id
	pet["nickname"] = str(pet.get("nickname", "水母喵"))
	pet["personality_id"] = str(pet.get("personality_id", "curious"))
	pet["stage"] = clampi(int(pet.get("stage", 1)), 1, int(species.get("max_stage", 5)))
	pet["growth_exp"] = max(int(pet.get("growth_exp", 0)), 0)
	pet["hunger"] = clampi(int(pet.get("hunger", species.get("default_hunger", 80))), 0, 100)
	pet["mood"] = clampi(int(pet.get("mood", species.get("default_mood", 70))), 0, 100)
	pet["health"] = str(pet.get("health", "healthy"))
	if str(pet["health"]) == "needs_care":
		pet["health"] = "sick"
	pet["vitality"] = clampi(int(pet.get("vitality", 100)), 0, 100)
	if not pet.get("visual_params") is Dictionary:
		pet["visual_params"] = {}
	if not pet.get("care_stats") is Dictionary:
		pet["care_stats"] = _default_care_stats()
	else:
		var care_stats: Dictionary = pet["care_stats"] as Dictionary
		var defaults: Dictionary = _default_care_stats()
		for key in defaults.keys():
			if not care_stats.has(key):
				care_stats[key] = defaults[key]
		pet["care_stats"] = care_stats
	return pet


func _default_care_stats() -> Dictionary:
	return {
		"touch_growth_exp_today": 0,
		"touch_exp_date": "",
		"last_touch_effect_at": 0.0,
		"touch_cap_notified_date": ""
	}


func _grant_missing_starter_eggs(nursery: Dictionary, pet_count: int, capacity: int, pets: Dictionary) -> void:
	var eggs: Array = nursery.get("eggs", []) as Array
	var missing: int = max(0, min(STARTER_CAPACITY, capacity) - pet_count - eggs.size())
	for _index in range(missing):
		var existing_ids: Dictionary = {}
		var existing_pet_ids: Dictionary = {}
		for existing_pet_id in pets.keys():
			existing_pet_ids[str(existing_pet_id)] = true
		for egg in eggs:
			existing_ids[str((egg as Dictionary).get("egg_id", ""))] = true
			var queued_pet_id: String = str((egg as Dictionary).get("pet_id", ""))
			if not queued_pet_id.is_empty():
				existing_pet_ids[queued_pet_id] = true
		var candidate: int = eggs.size() + pet_count + 1
		var egg_id: String = "egg_%03d" % candidate
		while existing_ids.has(egg_id):
			candidate += 1
			egg_id = "egg_%03d" % candidate
		var pet_candidate: int = max(1, pet_count + eggs.size() + 1)
		var pet_id: String = "jc_%03d" % pet_candidate
		while existing_pet_ids.has(pet_id):
			pet_candidate += 1
			pet_id = "jc_%03d" % pet_candidate
		var personality_index: int = (pet_count + eggs.size()) % STARTER_PERSONALITIES.size()
		eggs.append({
			"egg_id": egg_id,
			"pet_id": pet_id,
			"species_id": "normal_jellycat",
			"personality_id": STARTER_PERSONALITIES[personality_index],
			"source": "legacy_companion",
			"required_clicks": 10,
			"current_clicks": 0,
			"is_hatched": false
		})
	nursery["eggs"] = eggs
	nursery["active_egg_id"] = str(eggs[0].get("egg_id", "")) if not eggs.is_empty() else ""


func _next_egg_id() -> String:
	var max_id: int = 0
	for egg in get_nursery_eggs():
		var egg_id: String = str(egg.get("egg_id", ""))
		var digits: String = egg_id.trim_prefix("egg_")
		if digits.is_valid_int():
			max_id = max(max_id, int(digits))
	return "egg_%03d" % (max_id + 1)


func _next_pet_id() -> String:
	var max_id: int = 0
	var used_ids: Dictionary = {}
	for pet_id in get_pet_ids():
		used_ids[pet_id] = true
		var digits: String = pet_id.trim_prefix("jc_")
		if digits.is_valid_int():
			max_id = max(max_id, int(digits))
	for egg in get_nursery_eggs():
		var queued_pet_id: String = str(egg.get("pet_id", ""))
		if queued_pet_id.is_empty():
			continue
		used_ids[queued_pet_id] = true
		var digits: String = queued_pet_id.trim_prefix("jc_")
		if digits.is_valid_int():
			max_id = max(max_id, int(digits))
	var candidate: String = "jc_%03d" % (max_id + 1)
	while used_ids.has(candidate):
		max_id += 1
		candidate = "jc_%03d" % (max_id + 1)
	return candidate


func _get_or_create_dictionary(key: String) -> Dictionary:
	var value: Variant = data.get(key, {})
	if value is Dictionary:
		return value as Dictionary
	data[key] = {}
	return data[key] as Dictionary
