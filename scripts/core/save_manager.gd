extends Node

const SAVE_PATH: String = "user://save_game.json"
const AUTO_FLUSH_SECONDS: float = 5.0

var save_path: String = SAVE_PATH
var dirty: bool = false
var flush_timer: float = 0.0
var load_blocked: bool = false


func _process(delta: float) -> void:
	if not dirty or load_blocked:
		return
	flush_timer += delta
	if flush_timer >= AUTO_FLUSH_SECONDS:
		flush_save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		flush_save()


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func set_save_path_for_test(path: String) -> bool:
	if not path.begins_with("user://") or path == SAVE_PATH:
		return false
	save_path = path
	dirty = false
	flush_timer = 0.0
	load_blocked = false
	return true


func use_production_save_path() -> void:
	save_path = SAVE_PATH
	dirty = false
	flush_timer = 0.0
	load_blocked = false


func save_game() -> bool:
	if load_blocked:
		RuntimeLogger.log_save("save_game blocked: invalid or unsupported save must be recovered or explicitly reset")
		return false
	if GameState == null:
		RuntimeLogger.log_save("save_game failed: GameState missing")
		return false
	GameState.set_timestamp("last_saved_at", Time.get_datetime_string_from_system(), false)
	var payload: String = JSON.stringify(GameState.to_save_dict(), "\t", true, true)
	if not _write_atomic(save_path, payload, true):
		RuntimeLogger.log_save("save_game failed: atomic write did not complete")
		return false
	dirty = false
	flush_timer = 0.0
	RuntimeLogger.log_save("save_game success")
	return true


func request_save() -> void:
	if load_blocked:
		return
	if not dirty:
		flush_timer = 0.0
	dirty = true


func flush_save() -> bool:
	if not dirty or load_blocked:
		return false
	return save_game()


func load_game() -> bool:
	if not has_save():
		if _recover_candidate(_previous_path(), false):
			return true
		if _recover_candidate(_backup_path(), false):
			return true
		load_blocked = false
		RuntimeLogger.log_save("load_game failed: no save file or recoverable transaction")
		return false
	var raw: String = _read_text(save_path)
	if raw.is_empty():
		if _recover_candidate(_previous_path(), true) or _recover_candidate(_backup_path(), true):
			return true
		load_blocked = true
		RuntimeLogger.log_save("load_game blocked: save is empty and no valid recovery file exists")
		return false
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		if _recover_candidate(_previous_path(), true) or _recover_candidate(_backup_path(), true):
			return true
		load_blocked = true
		RuntimeLogger.log_save("load_game blocked: invalid JSON retained for recovery")
		push_warning("Save file is invalid. Original data is preserved; no new save will overwrite it.")
		return false
	var prepared: Dictionary = GameState.prepare_data(parsed as Dictionary)
	if not bool(prepared.get("ok", false)):
		load_blocked = true
		RuntimeLogger.log_save("load_game blocked: %s" % str(prepared.get("reason", "invalid save")))
		push_warning("Save data is unsupported or invalid (%s). Original data is preserved." % str(prepared.get("reason", "invalid save")))
		return false
	if not GameState.set_data(prepared["data"] as Dictionary):
		load_blocked = true
		return false
	load_blocked = false
	if bool(prepared.get("migrated", false)):
		if not save_game():
			push_warning("Save migration loaded, but durable migration did not complete; the original file remains available.")
	RuntimeLogger.log_save("load_game success")
	return true


func recover_from_backup() -> bool:
	return _recover_candidate(_backup_path(), has_save())


func reset_save() -> void:
	_remove_if_exists(save_path)
	_remove_if_exists(_backup_path())
	_remove_if_exists(save_path + ".tmp")
	_remove_if_exists(save_path + ".bak.tmp")
	_remove_if_exists(save_path + ".previous")
	_remove_if_exists(save_path + ".corrupt")
	GameState.reset_to_default()
	dirty = false
	flush_timer = 0.0
	load_blocked = false
	RuntimeLogger.log_save("reset_save success")


func get_save_path() -> String:
	return save_path


func get_backup_path() -> String:
	return _backup_path()


func _write_atomic(target_path: String, contents: String, update_backup: bool) -> bool:
	var temporary_path: String = target_path + ".tmp"
	var backup_path: String = _backup_path()
	var previous_path: String = _previous_path()
	if not _write_text(temporary_path, contents):
		return false
	var verify_text: String = _read_text(temporary_path)
	var verify_value: Variant = JSON.parse_string(verify_text)
	if verify_text != contents or not (verify_value is Dictionary):
		_remove_if_exists(temporary_path)
		return false
	var prepared: Dictionary = GameState.prepare_data(verify_value as Dictionary)
	if not bool(prepared.get("ok", false)):
		_remove_if_exists(temporary_path)
		return false
	if update_backup and FileAccess.file_exists(target_path):
		var old_text: String = _read_text(target_path)
		var parsed_old: Variant = JSON.parse_string(old_text)
		if old_text.is_empty() or not (parsed_old is Dictionary):
			_remove_if_exists(temporary_path)
			return false
		var backup_temporary: String = backup_path + ".tmp"
		if not _write_text(backup_temporary, old_text) or _read_text(backup_temporary) != old_text:
			_remove_if_exists(temporary_path)
			_remove_if_exists(backup_temporary)
			return false
		_remove_if_exists(backup_path)
		if not _rename(backup_temporary, backup_path):
			_remove_if_exists(temporary_path)
			return false
	var had_target: bool = FileAccess.file_exists(target_path)
	if had_target:
		_remove_if_exists(previous_path)
		if not _rename(target_path, previous_path):
			_remove_if_exists(temporary_path)
			return false
	if not _rename(temporary_path, target_path):
		if had_target:
			_rename(previous_path, target_path)
		return false
	if had_target:
		_remove_if_exists(previous_path)
	return _read_text(target_path) == contents


func _write_text(path: String, contents: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(contents)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	return error == OK


func _read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var contents: String = file.get_as_text()
	file.close()
	return contents


func _rename(source_path: String, target_path: String) -> bool:
	var error: Error = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(source_path),
		ProjectSettings.globalize_path(target_path)
	)
	return error == OK


func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _backup_path() -> String:
	return save_path + ".bak"


func _previous_path() -> String:
	return save_path + ".previous"


func _recover_candidate(candidate_path: String, preserve_current: bool) -> bool:
	if not FileAccess.file_exists(candidate_path):
		return false
	var candidate_text: String = _read_text(candidate_path)
	var parsed: Variant = JSON.parse_string(candidate_text)
	if candidate_text.is_empty() or not (parsed is Dictionary):
		return false
	var prepared: Dictionary = GameState.prepare_data(parsed as Dictionary)
	if not bool(prepared.get("ok", false)) or not GameState.set_data(prepared["data"] as Dictionary):
		return false
	if preserve_current and has_save():
		var corrupt_path: String = save_path + ".corrupt"
		if not _write_text(corrupt_path, _read_text(save_path)):
			return false
	load_blocked = false
	dirty = false
	var restored_text: String = JSON.stringify(GameState.to_save_dict(), "\t", true, true)
	if not _write_atomic(save_path, restored_text, false):
		load_blocked = true
		return false
	if candidate_path != _backup_path():
		_remove_if_exists(candidate_path)
	RuntimeLogger.log_save("recovered save from %s" % candidate_path.get_file())
	return true
