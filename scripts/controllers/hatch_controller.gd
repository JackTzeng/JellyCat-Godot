extends Control

const DOS_STYLE = preload("res://scripts/ui/dos_style.gd")

@onready var egg_button: Button = %EggButton
@onready var progress_label: Label = %ProgressLabel
@onready var hint_label: Label = %HintLabel

func _ready() -> void:
	DOS_STYLE.apply(self)
	RuntimeLogger.log_info("Hatch entered")
	if not GameState.has_unhatched_egg():
		RuntimeLogger.log_error("No egg found")
		if GameState.has_jellycat():
			SceneRouter.go_aquarium()
		else:
			SceneRouter.go_title()
		return
	egg_button.pressed.connect(_on_egg_pressed)
	_update_view()


func _on_egg_pressed() -> void:
	var egg_id: String = GameState.get_active_egg_id()
	var egg: Dictionary = HatchSystem.tap_egg(egg_id)
	if egg.is_empty():
		hint_label.text = "No egg is ready to hatch."
		return
	RuntimeLogger.log_action("Egg tapped: %d / %d" % [int(egg.get("current_clicks", 0)), int(egg.get("required_clicks", 10))])
	_update_view()
	if bool(egg.get("is_hatched", false)):
		RuntimeLogger.log_info("Egg hatched")
		hint_label.text = "A new JellyCat joined the aquarium!"
		await get_tree().create_timer(0.45).timeout
		if not is_inside_tree():
			return
		SceneRouter.go_aquarium()


func _update_view() -> void:
	var egg: Dictionary = GameState.get_nursery_egg(GameState.get_active_egg_id())
	if egg.is_empty():
		progress_label.text = "0 / 10"
		return
	progress_label.text = "%d / %d" % [int(egg.get("current_clicks", 0)), int(egg.get("required_clicks", 10))]
	hint_label.text = "Tap the egg to hatch it. %d egg(s) remain in the nursery." % GameState.get_nursery_eggs().size()
