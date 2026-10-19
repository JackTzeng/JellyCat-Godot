extends Node

signal time_scale_changed(previous_scale: int, new_scale: int)

const SECONDS_PER_DAY: float = 86400.0
const ALLOWED_TIME_SCALES: Array[int] = [1, 60]

var time_scale: int = 1
var _gameplay_time_offset_seconds: float = 0.0
var _online_cleanliness_fractional_decay: float = 0.0


func _process(delta: float) -> void:
	_gameplay_time_offset_seconds += maxf(delta, 0.0) * float(maxi(time_scale - 1, 0))


func get_time_scale() -> int:
	return time_scale


func set_time_scale(value: int) -> bool:
	if not ALLOWED_TIME_SCALES.has(value):
		return false
	if value == time_scale:
		return true
	var previous_scale: int = time_scale
	time_scale = value
	time_scale_changed.emit(previous_scale, time_scale)
	return true


func scale_delta(delta: float) -> float:
	return maxf(delta, 0.0) * float(time_scale)


func gameplay_now_seconds(real_now_seconds: float = -1.0) -> float:
	var now: float = Time.get_unix_time_from_system() if real_now_seconds < 0.0 else real_now_seconds
	return now + _gameplay_time_offset_seconds


func consume_online_cleanliness_decay(elapsed_seconds: float, decay_per_day: float) -> int:
	if elapsed_seconds <= 0.0 or decay_per_day <= 0.0:
		return 0
	_online_cleanliness_fractional_decay += elapsed_seconds * decay_per_day / SECONDS_PER_DAY
	var decay_points: int = int(floor(_online_cleanliness_fractional_decay + 0.000001))
	_online_cleanliness_fractional_decay = maxf(_online_cleanliness_fractional_decay - float(decay_points), 0.0)
	return decay_points

func now_string() -> String:
	return Time.get_datetime_string_from_system()


func unix_now() -> int:
	return int(Time.get_unix_time_from_system())


func seconds_since_datetime_string(date_text: String) -> float:
	if date_text.is_empty():
		return 0.0
	var unix: int = Time.get_unix_time_from_datetime_string(date_text)
	if unix <= 0:
		return 0.0
	return max(0.0, float(unix_now() - unix))


func days_from_seconds(seconds: float) -> float:
	return seconds / SECONDS_PER_DAY
