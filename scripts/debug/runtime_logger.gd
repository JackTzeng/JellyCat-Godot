extends Node

signal logs_changed

const MAX_LOGS: int = 100
const LOG_PATH: String = "user://jellycat_runtime.log"

var logs: Array = []
var throttled_log_times: Dictionary = {}

func log_info(message: String) -> void:
	_add_log("INFO", message)


func log_action(message: String) -> void:
	_add_log("ACTION", message)


func log_state(message: String) -> void:
	_add_log("STATE", message)


func log_save(message: String) -> void:
	_add_log("SAVE", message)


func log_error(message: String) -> void:
	_add_log("ERROR", message)


func log_info_throttled(key: String, message: String, seconds: float = 2.0) -> void:
	if _can_log_throttled("INFO:%s" % key, seconds):
		log_info(message)


func log_error_throttled(key: String, message: String, seconds: float = 2.0) -> void:
	if _can_log_throttled("ERROR:%s" % key, seconds):
		log_error(message)


func get_logs() -> Array:
	return logs.duplicate(true)


func clear() -> void:
	logs.clear()
	throttled_log_times.clear()
	logs_changed.emit()


func get_log_text() -> String:
	var lines: Array = []
	for entry in logs:
		if entry is Dictionary:
			lines.append("[%s] %s %s" % [str(entry.get("time", "")), str(entry.get("level", "")), str(entry.get("message", ""))])
	return "\n".join(lines)


func save_to_file() -> bool:
	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		log_error("save runtime log failed: %s" % LOG_PATH)
		return false
	file.store_string(get_log_text())
	file.close()
	log_save("runtime log saved: %s" % LOG_PATH)
	return true


func _add_log(level: String, message: String) -> void:
	var safe_message: String = message.strip_edges()
	if safe_message.is_empty():
		safe_message = "(empty message)"
	var now: Dictionary = Time.get_time_dict_from_system()
	var entry: Dictionary = {
		"time": "%02d:%02d:%02d" % [int(now.get("hour", 0)), int(now.get("minute", 0)), int(now.get("second", 0))],
		"level": level,
		"message": safe_message
	}
	logs.append(entry)
	while logs.size() > MAX_LOGS:
		logs.pop_front()
	logs_changed.emit()


func _can_log_throttled(key: String, seconds: float) -> bool:
	var now: float = Time.get_unix_time_from_system()
	var last: float = float(throttled_log_times.get(key, -999999.0))
	if now - last < seconds:
		return false
	throttled_log_times[key] = now
	return true
