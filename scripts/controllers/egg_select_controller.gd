extends Control

func _ready() -> void:
	%VersionLabel.text = VersionManager.get_display_text()
	%SelectButton.pressed.connect(_on_select_pressed)
	%BackButton.pressed.connect(SceneRouter.go_title)
	var eggs: Array[Dictionary] = EggSystem.ensure_starter_eggs()
	if eggs.is_empty():
		%SelectButton.disabled = true
		return
	if GameState.get_nursery_egg(GameState.get_active_egg_id()).is_empty():
		GameState.set_active_egg_id(str(eggs[0].get("egg_id", "")))
	RuntimeLogger.log_info("Egg Select entered")


func _on_select_pressed() -> void:
	var egg_id: String = GameState.get_active_egg_id()
	RuntimeLogger.log_action("Egg selected: %s" % egg_id)
	if not EggSystem.select_starter_egg(egg_id):
		return
	RuntimeLogger.log_save("Save after egg selected")
	SceneRouter.go_hatch()
