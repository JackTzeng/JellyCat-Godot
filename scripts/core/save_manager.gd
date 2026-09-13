extends Node

const SAVE_PATH: String = "user://save_game.json"
const AUTO_FLUSH_SECONDS: float = 5.0

var dirty: bool = false
var flush_timer: float = 0.0

func _process(delta: float) -> void:
	if not dirty:
		return
	flush_timer += delta
	if flush_timer >= AUTO_FLUSH_SECONDS:
		flush_save()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	if GameState == null:
		RuntimeLogger.log_save("save_game failed: GameState missing")
		return false
	GameState.set_timestamp("last_saved_at", Time.get_datetime_string_from_system(), false)
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		RuntimeLogger.log_save("save_game failed")
		push_error("Unable to open save file for writing: %s" % SAVE_PATH)
		return false
	file.store_string(JSON.stringify(GameState.to_save_dict(), "\t"))
	file.close()
	dirty = false
	flush_timer = 0.0
	RuntimeLogger.log_save("save_game success")
	return true


func request_save() -> void:
	dirty = true
	flush_timer = 0.0


func flush_save() -> bool:
	if not dirty:
		return false
	return save_game()


func load_game() -> bool:
	if not has_save():
		RuntimeLogger.log_save("load_game failed: no save file")
		return false
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		RuntimeLogger.log_save("load_game failed")
		push_error("Unable to open save file: %s" % SAVE_PATH)
		return false
	var raw: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		RuntimeLogger.log_save("load_game failed: invalid JSON")
		push_warning("Save file is invalid. Resetting to default state.")
		GameState.reset_to_default()
		return false
	GameState.set_data(parsed as Dictionary)
	RuntimeLogger.log_save("load_game success")
	return true


func reset_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	GameState.reset_to_default()
	dirty = false
	flush_timer = 0.0
	RuntimeLogger.log_save("reset_save success")


func get_save_path() -> String:
	return SAVE_PATH
