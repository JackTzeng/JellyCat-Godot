extends Node

const SAVE_PATH: String = "user://save_game.json"
const AUTO_FLUSH_SECONDS: float = 5.0
const BACKUP_ROTATION_SECONDS: int = 62
const WRITE_INTERRUPT_POINTS_FOR_TEST: Array[String] = [
	"after_save_temp_verified",
	"after_backup_temp_verified",
	"after_backup_promotion",
	"before_main_replace",
	"after_main_replace"
]

var save_path: String = SAVE_PATH
var dirty: bool = false
var flush_timer: float = 0.0
var load_blocked: bool = false
var _write_interrupt_point_for_test: String = ""


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
	_write_interrupt_point_for_test = ""
	return true


func use_production_save_path() -> void:
	save_path = SAVE_PATH
	dirty = false
	flush_timer = 0.0
	load_blocked = false
	_write_interrupt_point_for_test = ""


func set_write_interruption_point_for_test(point: String) -> bool:
	if point.is_empty():
		_write_interrupt_point_for_test = ""
		return true
	if not WRITE_INTERRUPT_POINTS_FOR_TEST.has(point):
		return false
	_write_interrupt_point_for_test = point
	return true


func _interrupt_write_for_test(point: String) -> bool:
	if _write_interrupt_point_for_test != point:
		return false
	_write_interrupt_point_for_test = ""
	return true


func save_game(force_backup_refresh: bool = false) -> bool:
	if load_blocked:
		RuntimeLogger.log_save("save_game blocked: invalid or unsupported save must be recovered or explicitly reset")
		return false
	if GameState == null:
		RuntimeLogger.log_save("save_game failed: GameState missing")
		return false
	GameState.set_timestamp("last_saved_at", Time.get_datetime_string_from_system(), false)
	var payload: String = JSON.stringify(GameState.to_save_dict(), "	", true, true)
	if not _write_atomic(save_path, payload, true, force_backup_refresh):
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
		if _recover_from_any_recovery_file(false):
			return true
		load_blocked = false
		RuntimeLogger.log_save("load_game failed: no save file or recoverable transaction")
		return false
	var raw: String = _read_text(save_path)
	if raw.is_empty():
		if _recover_from_any_recovery_file(true):
			return true
		load_blocked = true
		RuntimeLogger.log_save("load_game blocked: save is empty and no valid recovery file exists")
		return false
	var parsed: Variant = _parse_json(raw)
	if not (parsed is Dictionary):
		if _recover_from_any_recovery_file(true):
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
		if not save_game(true):
			push_warning("Save migration loaded, but durable migration did not complete; the original file remains available.")
	RuntimeLogger.log_save("load_game success")
	return true


func _parse_json(text: String) -> Variant:
	var parser: JSON = JSON.new()
	if parser.parse(text) != OK:
		return null
	return parser.data


func recover_from_backup() -> bool:
	return _recover_from_any_backup(has_save())


func reset_save() -> void:
	_remove_if_exists(save_path)
	_remove_if_exists(_backup_path())
	_remove_if_exists(_backup_secondary_path())
	_remove_if_exists(save_path + ".tmp")
	_remove_if_exists(save_path + ".bak.tmp")
	_remove_if_exists(save_path + ".bak2.tmp")
	_remove_if_exists(save_path + ".previous")
	_remove_if_exists(save_path + ".corrupt")
	GameState.reset_to_default()
	dirty = false
	flush_timer = 0.0
	load_blocked = false
	_write_interrupt_point_for_test = ""
	RuntimeLogger.log_save("reset_save success")


func get_save_path() -> String:
	return save_path


func get_backup_path() -> String:
	return _backup_path()


func _write_atomic(target_path: String, contents: String, update_backup: bool, force_backup_refresh: bool = false) -> bool:
	var temporary_path: String = target_path + ".tmp"
	if not _write_text(temporary_path, contents):
		return false
	var verify_text: String = _read_text(temporary_path)
	if verify_text != contents or not _is_valid_save_text(verify_text):
		_remove_if_exists(temporary_path)
		return false
	if _interrupt_write_for_test("after_save_temp_verified"):
		return false
	var had_target: bool = FileAccess.file_exists(target_path)
	if update_backup:
		var backup_contents: String = contents
		if had_target:
			backup_contents = _read_text(target_path)
			if not _is_valid_save_text(backup_contents):
				_remove_if_exists(temporary_path)
				return false
			if force_backup_refresh and _read_text(_backup_path()) != backup_contents:
				if not _preserve_oldest_backup_before_primary_refresh():
					_remove_if_exists(temporary_path)
					return false
		if not _ensure_backup_slots(backup_contents):
			_remove_if_exists(temporary_path)
			return false
		if had_target:
			var refresh_path: String = _oldest_backup_due_for_refresh()
			if force_backup_refresh and _read_text(_backup_path()) != backup_contents:
				refresh_path = _backup_path()
			if not refresh_path.is_empty() and not _write_backup_atomically(refresh_path, backup_contents):
				_remove_if_exists(temporary_path)
				return false
	if _interrupt_write_for_test("before_main_replace"):
		return false
	if not _rename(temporary_path, target_path):
		_remove_if_exists(temporary_path)
		return false
	if _interrupt_write_for_test("after_main_replace"):
		return false
	return _read_text(target_path) == contents and _is_valid_save_text(_read_text(target_path))


func _ensure_backup_slots(contents: String) -> bool:
	for backup_path in _backup_paths():
		if FileAccess.file_exists(backup_path) and _is_valid_save_text(_read_text(backup_path)):
			continue
		if not _write_backup_atomically(backup_path, contents):
			return false
	return true


func _write_backup_atomically(backup_path: String, contents: String) -> bool:
	var backup_temporary: String = backup_path + ".tmp"
	if not _write_text(backup_temporary, contents):
		_remove_if_exists(backup_temporary)
		return false
	var verify_text: String = _read_text(backup_temporary)
	if verify_text != contents or not _is_valid_save_text(verify_text):
		_remove_if_exists(backup_temporary)
		return false
	if _interrupt_write_for_test("after_backup_temp_verified"):
		return false
	if not _rename(backup_temporary, backup_path):
		_remove_if_exists(backup_temporary)
		return false
	if _interrupt_write_for_test("after_backup_promotion"):
		return false
	return _is_valid_save_text(_read_text(backup_path))


func _oldest_backup_due_for_refresh() -> String:
	var paths: Array[String] = _backup_paths()
	var oldest_path: String = _oldest_backup_path()
	var newest_mtime: int = FileAccess.get_modified_time(paths[0])
	for candidate_path in paths:
		var candidate_mtime: int = FileAccess.get_modified_time(candidate_path)
		if candidate_mtime > newest_mtime:
			newest_mtime = candidate_mtime
	if int(Time.get_unix_time_from_system()) - newest_mtime < BACKUP_ROTATION_SECONDS:
		return ""
	return oldest_path


func _preserve_oldest_backup_before_primary_refresh() -> bool:
	var primary_path: String = _backup_path()
	var secondary_path: String = _backup_secondary_path()
	if not FileAccess.file_exists(primary_path) or not _is_valid_save_text(_read_text(primary_path)):
		return true
	if FileAccess.file_exists(secondary_path) and _is_valid_save_text(_read_text(secondary_path)):
		if FileAccess.get_modified_time(secondary_path) <= FileAccess.get_modified_time(primary_path):
			return true
	return _rename(primary_path, secondary_path)


func _oldest_backup_path() -> String:
	var paths: Array[String] = _backup_paths()
	var oldest_path: String = paths[0]
	var oldest_mtime: int = FileAccess.get_modified_time(oldest_path)
	for candidate_path in paths:
		var candidate_mtime: int = FileAccess.get_modified_time(candidate_path)
		if candidate_mtime < oldest_mtime:
			oldest_path = candidate_path
			oldest_mtime = candidate_mtime
	return oldest_path


func _is_valid_save_text(text: String) -> bool:
	if text.is_empty():
		return false
	var parsed: Variant = _parse_json(text)
	if not (parsed is Dictionary):
		return false
	var prepared: Dictionary = GameState.prepare_data(parsed as Dictionary)
	return bool(prepared.get("ok", false))


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


func _backup_secondary_path() -> String:
	return save_path + ".bak2"


func _backup_paths() -> Array[String]:
	var paths: Array[String] = [_backup_path(), _backup_secondary_path()]
	return paths


func _backup_paths_newest_first() -> Array[String]:
	var paths: Array[String] = _backup_paths()
	var first_exists: bool = FileAccess.file_exists(paths[0])
	var second_exists: bool = FileAccess.file_exists(paths[1])
	if second_exists and (not first_exists or FileAccess.get_modified_time(paths[1]) > FileAccess.get_modified_time(paths[0])):
		return [paths[1], paths[0]]
	return paths


func _recover_from_any_backup(preserve_current: bool) -> bool:
	for candidate_path in _backup_paths_newest_first():
		if _recover_candidate(candidate_path, preserve_current):
			return true
	return false


func _recover_from_any_recovery_file(preserve_current: bool) -> bool:
	for candidate_path in _recovery_paths_newest_first():
		if _recover_candidate(candidate_path, preserve_current):
			return true
	return false


func _recovery_paths_newest_first() -> Array[String]:
	var paths: Array[String] = []
	var candidates: Array[String] = [_previous_path(), _backup_path(), _backup_secondary_path()]
	for candidate_path in candidates:
		if FileAccess.file_exists(candidate_path):
			paths.append(candidate_path)
	for left_index in range(paths.size()):
		for right_index in range(left_index + 1, paths.size()):
			if FileAccess.get_modified_time(paths[right_index]) > FileAccess.get_modified_time(paths[left_index]):
				var older_path: String = paths[left_index]
				paths[left_index] = paths[right_index]
				paths[right_index] = older_path
	return paths


func _previous_path() -> String:
	return save_path + ".previous"


func _recover_candidate(candidate_path: String, preserve_current: bool) -> bool:
	if not FileAccess.file_exists(candidate_path):
		return false
	var candidate_text: String = _read_text(candidate_path)
	var parsed: Variant = _parse_json(candidate_text)
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
	if not _is_backup_path(candidate_path):
		_remove_if_exists(candidate_path)
	RuntimeLogger.log_save("recovered save from %s" % candidate_path.get_file())
	return true


func _is_backup_path(candidate_path: String) -> bool:
	return candidate_path == _backup_path() or candidate_path == _backup_secondary_path()
