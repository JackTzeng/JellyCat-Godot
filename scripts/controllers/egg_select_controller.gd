extends Control

func _ready() -> void:
	%VersionLabel.text = VersionManager.get_display_text()
	%SelectButton.pressed.connect(_on_select_pressed)
	%BackButton.pressed.connect(SceneRouter.go_title)
	RuntimeLogger.log_info("Egg Select entered")


func _on_select_pressed() -> void:
	RuntimeLogger.log_action("Egg selected: normal_jellycat")
	EggSystem.select_starter_egg()
	RuntimeLogger.log_save("Save after egg selected")
	SceneRouter.go_hatch()
