extends Control

@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	status_label.text = "Loading JellyCat..."
	await get_tree().process_frame
	GameApp.boot()
	status_label.text = "Ready"
	await get_tree().create_timer(0.25).timeout
	SceneRouter.route_after_boot()
