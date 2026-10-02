extends Control

@onready var version_label: Label = %VersionLabel
@onready var continue_button: Button = %ContinueButton

func _ready() -> void:
	version_label.text = VersionManager.get_display_text()
	continue_button.disabled = not SaveManager.has_save()
	%NewGameButton.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	%ResetButton.pressed.connect(_on_reset_pressed)
	RuntimeLogger.log_info("Title entered")


func _on_new_game_pressed() -> void:
	RuntimeLogger.log_action("New game clicked")
	SaveManager.reset_save()
	EggSystem.ensure_starter_eggs()
	SaveManager.save_game()
	SceneRouter.go_egg_select()


func _on_continue_pressed() -> void:
	RuntimeLogger.log_action("Continue clicked")
	GameApp.boot()
	SceneRouter.route_after_boot()


func _on_reset_pressed() -> void:
	RuntimeLogger.log_action("Reset save clicked")
	SaveManager.reset_save()
	continue_button.disabled = true
