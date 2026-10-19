extends Control

const DOS_STYLE = preload("res://scripts/ui/dos_style.gd")

@onready var egg_button: Button = %EggButton
@onready var egg_artwork: TextureRect = %EggArtwork
@onready var progress_label: Label = %ProgressLabel
@onready var hint_label: Label = %HintLabel

const EGG_IDLE: Texture2D = preload("res://assets/eggs/egg_idle_v2_64.png")
const EGG_CRACK_1: Texture2D = preload("res://assets/eggs/egg_crack1_v2_64.png")
const EGG_CRACK_2: Texture2D = preload("res://assets/eggs/egg_crack2_v2_64.png")
const EGG_CRACK_3: Texture2D = preload("res://assets/eggs/egg_crack3_v2_64.png")
const EGG_HATCH_BURST: Texture2D = preload("res://assets/eggs/egg_hatch_burst_v2_64.png")

var route_timer: Timer
var route_pending: bool = false

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
	egg_artwork.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_update_view()


func _on_egg_pressed() -> void:
	if route_pending or not is_inside_tree():
		return
	var egg_id: String = GameState.get_active_egg_id()
	var egg: Dictionary = HatchSystem.tap_egg(egg_id)
	if egg.is_empty():
		hint_label.text = "目前沒有可孵化的蛋。"
		return
	RuntimeLogger.log_action("Egg tapped: %d / %d" % [int(egg.get("current_clicks", 0)), int(egg.get("required_clicks", 10))])
	_update_view()
	if bool(egg.get("is_hatched", false)):
		route_pending = true
		egg_button.disabled = true
		egg_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		egg_artwork.texture = EGG_HATCH_BURST
		RuntimeLogger.log_info("Egg hatched")
		hint_label.text = "新的水母喵加入水族箱了！"
		route_timer = Timer.new()
		route_timer.one_shot = true
		route_timer.wait_time = 0.45
		route_timer.timeout.connect(_route_to_aquarium)
		add_child(route_timer)
		route_timer.start()


func _route_to_aquarium() -> void:
	if route_pending and is_inside_tree():
		SceneRouter.go_aquarium()


func _update_view() -> void:
	var egg: Dictionary = GameState.get_nursery_egg(GameState.get_active_egg_id())
	var hatched_count: int = GameState.get_pet_ids().size()
	var total_egg_count: int = hatched_count + GameState.get_nursery_eggs().size()
	hint_label.text = "已孵化 %d／共 %d 顆" % [hatched_count, total_egg_count]
	if egg.is_empty():
		progress_label.text = "0 / 10"
		egg_artwork.texture = EGG_IDLE
		return
	var current_clicks: int = int(egg.get("current_clicks", 0))
	var required_clicks: int = maxi(1, int(egg.get("required_clicks", 10)))
	progress_label.text = "%d / %d" % [current_clicks, required_clicks]
	egg_artwork.texture = _get_egg_progress_texture(current_clicks, required_clicks)


func _get_egg_progress_texture(current_clicks: int, required_clicks: int) -> Texture2D:
	if current_clicks <= 0:
		return EGG_IDLE
	if current_clicks >= required_clicks:
		return EGG_HATCH_BURST
	var crack_stage: int = clampi(ceili(float(current_clicks) * 3.0 / float(maxi(required_clicks, 1))), 1, 3)
	match crack_stage:
		1:
			return EGG_CRACK_1
		2:
			return EGG_CRACK_2
		_:
			return EGG_CRACK_3
