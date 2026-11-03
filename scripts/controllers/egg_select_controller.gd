extends Control

const DOS_STYLE = preload("res://scripts/ui/dos_style.gd")

func _ready() -> void:
	DOS_STYLE.apply(self)
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
	if not _select_active_egg():
		return
	SceneRouter.go_hatch()


func _select_active_egg() -> bool:
	var egg_id: String = GameState.get_active_egg_id()
	RuntimeLogger.log_action("Egg selected: %s" % egg_id)
	if not EggSystem.select_starter_egg(egg_id):
		return false
	RuntimeLogger.log_save("Save after egg selected")
	return true
