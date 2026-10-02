extends Node

var data_tables: Dictionary = {}
var loaded: bool = false

func boot() -> void:
	RuntimeLogger.log_info("Game boot started")
	VersionManager.load_version()
	RuntimeLogger.log_info("Version loaded")
	load_data_tables()
	RuntimeLogger.log_info("Data tables loaded")
	if SaveManager.load_game():
		RuntimeLogger.log_save("Save loaded")
	else:
		RuntimeLogger.log_save("No save found")
	var elapsed_seconds: int = int(TimeManager.seconds_since_datetime_string(GameState.get_timestamp("last_saved_at")))
	CareSystem.apply_offline_care_decay(elapsed_seconds)
	CurrencySystem.apply_offline_income(elapsed_seconds)
	GameState.set_timestamp("last_opened_at", TimeManager.now_string(), false)
	GameState.set_timestamp("last_passive_coin_at", TimeManager.now_string(), false)
	loaded = true


func load_data_tables() -> void:
	data_tables = {
		"species": load_json_file("res://data/species.json"),
		"evolution": load_json_file("res://data/evolution.json"),
		"items": load_json_file("res://data/items.json"),
		"balance": load_json_file("res://data/balance.json"),
		"version": load_json_file("res://data/version.json"),
		"personalities": load_json_file("res://data/personalities.json")
	}


func load_json_file(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		RuntimeLogger.log_error("Missing data table: %s" % path)
		push_error("Missing JSON data file: %s" % path)
		return {}
	var raw: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		return parsed
	RuntimeLogger.log_error("Invalid data table: %s" % path)
	push_error("Invalid JSON data file: %s" % path)
	return {}


func get_table(table_name: String) -> Dictionary:
	return data_tables.get(table_name, {})


func get_balance_value(key: String, fallback: Variant = null) -> Variant:
	return get_table("balance").get(key, fallback)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveManager.flush_save()
