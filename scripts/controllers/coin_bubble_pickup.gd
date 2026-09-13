extends Button

signal collected(value: int, auto_collected: bool)

@export var value: int = 1
@export var auto_collect_seconds: float = 15.0

var already_collected: bool = false

func _ready() -> void:
	text = "+%d" % value
	pressed.connect(_on_pressed)
	_auto_collect_later()


func collect(auto_collected: bool = false) -> void:
	if already_collected:
		return
	already_collected = true
	collected.emit(value, auto_collected)
	queue_free()


func _on_pressed() -> void:
	collect(false)


func _auto_collect_later() -> void:
	await get_tree().create_timer(auto_collect_seconds).timeout
	if is_inside_tree():
		collect(true)
