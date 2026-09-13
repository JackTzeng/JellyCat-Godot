extends Control

@onready var egg_button: Button = %EggButton
@onready var progress_label: Label = %ProgressLabel
@onready var hint_label: Label = %HintLabel

func _ready() -> void:
	RuntimeLogger.log_info("Hatch entered")
	if not GameState.has_unhatched_egg():
		RuntimeLogger.log_error("No egg found")
		GameState.set_egg(EggSystem.create_starter_egg())
	egg_button.pressed.connect(_on_egg_pressed)
	_update_view()


func _on_egg_pressed() -> void:
	var egg: Dictionary = HatchSystem.tap_egg()
	RuntimeLogger.log_action("Egg tapped: %d / %d" % [int(egg.get("current_clicks", 0)), int(egg.get("required_clicks", 10))])
	_update_view()
	if bool(egg.get("is_hatched", false)):
		RuntimeLogger.log_info("Egg hatched")
		hint_label.text = "JellyCat was born!"
		await get_tree().create_timer(0.45).timeout
		SceneRouter.go_aquarium()


func _update_view() -> void:
	var egg: Variant = GameState.get_egg()
	if not (egg is Dictionary):
		progress_label.text = "0 / 10"
		return
	progress_label.text = "%d / %d" % [int(egg.get("current_clicks", 0)), int(egg.get("required_clicks", 10))]
