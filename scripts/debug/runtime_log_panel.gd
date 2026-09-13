extends PanelContainer

@onready var meta_label: Label = %MetaLabel
@onready var log_text: RichTextLabel = %LogText

func _ready() -> void:
	%ClearButton.pressed.connect(_on_clear_pressed)
	%CopyButton.pressed.connect(_on_copy_pressed)
	%SaveButton.pressed.connect(_on_save_pressed)
	RuntimeLogger.logs_changed.connect(refresh)
	refresh()


func refresh() -> void:
	meta_label.text = "Version: %s    Scene: %s    Save: %s" % [
		VersionManager.get_display_text(),
		_scene_name(),
		SaveManager.get_save_path()
	]
	log_text.text = RuntimeLogger.get_log_text()


func _on_clear_pressed() -> void:
	RuntimeLogger.clear()
	RuntimeLogger.log_info("runtime log cleared")


func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(RuntimeLogger.get_log_text())
	RuntimeLogger.log_info("runtime log copied to clipboard")


func _on_save_pressed() -> void:
	RuntimeLogger.save_to_file()


func _scene_name() -> String:
	if SceneRouter.current_scene_path.is_empty():
		return "Aquarium"
	return SceneRouter.current_scene_path.get_file().get_basename().capitalize()
