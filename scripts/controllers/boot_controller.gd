extends Control

@onready var status_label: Label = %StatusLabel

var route_timer: Timer

func _ready() -> void:
	status_label.text = "Loading JellyCat..."
	GameApp.boot()
	status_label.text = "Ready"
	route_timer = Timer.new()
	route_timer.one_shot = true
	route_timer.wait_time = 0.25
	route_timer.timeout.connect(_route_after_boot)
	add_child(route_timer)
	route_timer.start()


func _route_after_boot() -> void:
	if is_inside_tree():
		SceneRouter.route_after_boot()
