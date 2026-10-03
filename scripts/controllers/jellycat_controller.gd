extends Node2D

signal food_eaten(token_id: String, pet_id: String)

const DEFAULT_SPECIES_ID: String = "normal_jellycat"
const DEFAULT_MAX_STAGE: int = 5
const STAGE_TEXTURE_PATH: String = "res://assets/jellycats/%s/stages/stage_%d.png"

@onready var sprite: Sprite2D = %Sprite

var pet_id: String = ""
var bob_time: float = 0.0
var bob_phase: float = 0.0
var idle_time: float = 0.0
var roam_target: Vector2 = Vector2.ZERO
var behavior_state: String = "idle_roam"
var food_drop_id: String = ""
var post_meal_timer: float = 0.0
var touch_reaction_timer: float = 0.0
var current_stage: int = 0
var current_species_id: String = ""
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func set_pet_id(value: String) -> bool:
	if value.is_empty() or GameState.get_pet(value).is_empty():
		return false
	pet_id = value
	rng.randomize()
	bob_phase = rng.randf_range(0.0, TAU)
	return true


func _ready() -> void:
	if pet_id.is_empty():
		push_error("JellyCatActor requires an explicit pet_id")
		set_process(false)
		return
	refresh_pet()
	_choose_roam_target()


func _process(delta: float) -> void:
	if pet_id.is_empty():
		return
	bob_time += delta
	var offset: Vector2 = roam_target - position
	match behavior_state:
		"idle_roam":
			if offset.length() <= 10.0:
				idle_time -= delta
				if idle_time <= 0.0:
					_choose_roam_target()
			else:
				_move_toward(roam_target, float(GameApp.get_balance_value("actor_swim_speed", 32.0)), delta)
		"approach_food":
			_move_toward(roam_target, float(GameApp.get_balance_value("actor_food_chase_speed", 68.0)), delta)
		"post_meal":
			post_meal_timer -= delta
			if post_meal_timer <= 0.0:
				behavior_state = "idle_roam"
				_choose_roam_target()
		"touch_reaction":
			touch_reaction_timer -= delta
			if touch_reaction_timer <= 0.0:
				behavior_state = "idle_roam"
				_choose_roam_target()
		"eat":
			sprite.scale = Vector2.ONE * (1.0 + sin(bob_time * 14.0) * 0.05)
	if behavior_state == "idle_roam" or behavior_state == "approach_food":
		sprite.flip_h = offset.x < 0.0
	sprite.position.y = sin(bob_time * 2.0 + bob_phase) * 8.0
	sprite.rotation = sin(bob_time * 1.2 + bob_phase) * 0.025


func refresh_pet() -> void:
	if pet_id.is_empty():
		return
	var pet: Dictionary = GameState.get_pet(pet_id)
	if pet.is_empty():
		push_error("JellyCatActor lost its bound pet_id: %s" % pet_id)
		return
	set_stage(int(pet.get("stage", 1)), str(pet.get("species_id", DEFAULT_SPECIES_ID)))


func set_food_target(token_id: String, target_position: Vector2) -> bool:
	if behavior_state == "post_meal" or behavior_state == "touch_reaction" or behavior_state == "eat":
		return false
	food_drop_id = token_id
	roam_target = target_position
	behavior_state = "approach_food"
	return true


func clear_food_target(token_id: String) -> void:
	if food_drop_id != token_id:
		return
	food_drop_id = ""
	sprite.scale = Vector2.ONE
	behavior_state = "idle_roam"
	_choose_roam_target()


func begin_eating(token_id: String) -> void:
	if food_drop_id != token_id or behavior_state != "approach_food":
		return
	behavior_state = "eat"
	_finish_eating(token_id)


func _finish_eating(token_id: String) -> void:
	await get_tree().create_timer(0.45).timeout
	if is_inside_tree() and behavior_state == "eat" and food_drop_id == token_id:
		food_eaten.emit(token_id, pet_id)


func complete_meal(token_id: String) -> void:
	if food_drop_id != token_id:
		return
	sprite.scale = Vector2.ONE
	food_drop_id = ""
	behavior_state = "post_meal"
	post_meal_timer = float(GameApp.get_balance_value("actor_food_post_meal_seconds", 2.0))
	_choose_roam_target()


func react_to_touch() -> void:
	if behavior_state == "eat" or behavior_state == "post_meal":
		return
	behavior_state = "touch_reaction"
	touch_reaction_timer = 0.8


func can_accept_food() -> bool:
	return behavior_state == "idle_roam" or behavior_state == "approach_food"


func set_stage(stage: int, species_id: String) -> void:
	if pet_id.is_empty() or species_id.is_empty():
		return
	var clamped_stage: int = clampi(stage, 1, _get_max_stage(species_id))
	if clamped_stage == current_stage and species_id == current_species_id:
		return
	var stage_texture: Texture2D = _load_stage_texture(species_id, clamped_stage)
	if stage_texture == null:
		RuntimeLogger.log_error_throttled(
			"missing_jellycat_texture_%s_%d" % [species_id, clamped_stage],
			"Missing JellyCat texture: %s Stage %d" % [species_id, clamped_stage]
		)
		return
	current_stage = clamped_stage
	current_species_id = species_id
	sprite.texture = stage_texture


func _choose_roam_target() -> void:
	var x_radius: float = float(GameApp.get_balance_value("actor_roam_x_radius", 460.0))
	var y_radius: float = float(GameApp.get_balance_value("actor_roam_y_radius", 150.0))
	roam_target = Vector2(rng.randf_range(-x_radius, x_radius), rng.randf_range(-y_radius, y_radius))
	var minimum: float = float(GameApp.get_balance_value("actor_roam_idle_min_seconds", 1.5))
	var maximum: float = maxf(minimum, float(GameApp.get_balance_value("actor_roam_idle_max_seconds", 4.0)))
	idle_time = rng.randf_range(minimum, maximum)


func _move_toward(target: Vector2, speed: float, delta: float) -> void:
	var offset: Vector2 = target - position
	if offset.length() > 10.0:
		position = position.move_toward(target, speed * delta)


func _get_max_stage(species_id: String) -> int:
	var species: Variant = GameApp.get_table("species").get(species_id, {})
	if species is Dictionary:
		return max(int((species as Dictionary).get("max_stage", DEFAULT_MAX_STAGE)), 1)
	return DEFAULT_MAX_STAGE


func _load_stage_texture(species_id: String, stage: int) -> Texture2D:
	var texture_path: String = STAGE_TEXTURE_PATH % [species_id, stage]
	if not ResourceLoader.exists(texture_path):
		texture_path = STAGE_TEXTURE_PATH % [DEFAULT_SPECIES_ID, stage]
	if not ResourceLoader.exists(texture_path):
		return null
	return ResourceLoader.load(texture_path) as Texture2D
