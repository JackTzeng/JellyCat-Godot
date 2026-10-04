extends Button

const DOS_STYLE = preload("res://scripts/ui/dos_style.gd")

signal collected(token_id: String, value: int, auto_collected: bool, source_pet_id: String)

var token_id: String = ""
var source_pet_id: String = ""
var value: int = 1
var expires_at: float = 0.0
var already_collected: bool = false
var float_time: float = 0.0
var start_y: float = 0.0


func configure(drop: Dictionary) -> void:
	token_id = str(drop.get("token_id", ""))
	source_pet_id = str(drop.get("source_pet_id", ""))
	value = int(drop.get("value", 1))
	expires_at = float(drop.get("expires_at", 0.0))
	position = Vector2(float(drop.get("x", 0.0)), float(drop.get("y", 0.0))) - Vector2(36.0, 36.0)
	start_y = position.y


func _ready() -> void:
	DOS_STYLE.style_button(self)
	text = "+%d" % value
	pressed.connect(_on_pressed)


func _process(delta: float) -> void:
	if already_collected:
		return
	float_time += delta
	position.y = start_y + sin(float_time * 2.0) * 5.0
	if Time.get_unix_time_from_system() >= expires_at:
		collect(true)


func collect(auto_collected: bool = false) -> void:
	if already_collected:
		return
	already_collected = true
	disabled = true
	collected.emit(token_id, value, auto_collected, source_pet_id)


func animate_to_wallet(target_global_position: Vector2) -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", target_global_position, 0.38)
	tween.tween_property(self, "modulate:a", 0.0, 0.38)
	await tween.finished
	queue_free()


func discard() -> void:
	queue_free()


func _on_pressed() -> void:
	collect(false)
