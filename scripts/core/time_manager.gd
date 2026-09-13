extends Node

const SECONDS_PER_DAY: float = 86400.0

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
