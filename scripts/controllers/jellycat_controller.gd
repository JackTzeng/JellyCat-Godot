extends Node2D

signal food_eaten(token_id: String, pet_id: String)

const DEFAULT_SPECIES_ID: String = "normal_jellycat"
const DEFAULT_MAX_STAGE: int = 5
const STAGE_TEXTURE_PATH: String = "res://assets/jellycats/%s/stages/stage_%d.png"
const STAGE_ONE_BODY_RATIO: float = 0.18
const MAX_STAGE_BODY_RATIO: float = 0.22
const MAX_EAT_SCALE: float = 1.05
const MAX_SWIM_ROTATION: float = 0.025
const BOB_AMPLITUDE: float = 8.0

@onready var sprite: Sprite2D = %Sprite

var pet_id: String = ""
var bob_time: float = 0.0
var bob_phase: float = 0.0
var bob_offset: float = 0.0
var idle_time: float = 0.0
var roam_target: Vector2 = Vector2.ZERO
var behavior_state: String = "idle_roam"
var food_drop_id: String = ""
var post_meal_timer: float = 0.0
var touch_reaction_timer: float = 0.0
var current_stage: int = 0
var current_species_id: String = ""
var base_scale: float = STAGE_ONE_BODY_RATIO
var pulse_scale: float = 1.0
var water_bounds_local: Rect2 = Rect2()
var has_water_bounds: bool = false
var visible_texture_rect: Rect2 = Rect2()
var visible_texture_center: Vector2 = Vector2.ZERO
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
	pulse_scale = 1.0
	if behavior_state == "eat":
		pulse_scale = 1.0 + sin(bob_time * 14.0) * 0.05
	if behavior_state == "idle_roam" or behavior_state == "approach_food":
		sprite.flip_h = offset.x < 0.0
	bob_offset = sin(bob_time * 2.0 + bob_phase) * BOB_AMPLITUDE
	sprite.rotation = sin(bob_time * 1.2 + bob_phase) * MAX_SWIM_ROTATION
	_apply_sprite_pose()
	position = _clamp_to_water(position)


func refresh_pet() -> void:
	if pet_id.is_empty():
		return
	var pet: Dictionary = GameState.get_pet(pet_id)
	if pet.is_empty():
		push_error("JellyCatActor lost its bound pet_id: %s" % pet_id)
		return
	set_stage(int(pet.get("stage", 1)), str(pet.get("species_id", DEFAULT_SPECIES_ID)))


func set_water_bounds(bounds: Rect2) -> void:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	water_bounds_local = bounds
	has_water_bounds = true
	_update_base_scale()
	position = _clamp_to_water(position)
	roam_target = _clamp_to_water(roam_target)


func set_food_target(token_id: String, target_position: Vector2) -> bool:
	if behavior_state == "post_meal" or behavior_state == "touch_reaction" or behavior_state == "eat":
		return false
	food_drop_id = token_id
	roam_target = _clamp_to_water(target_position)
	behavior_state = "approach_food"
	return true


func clear_food_target(token_id: String) -> void:
	if food_drop_id != token_id:
		return
	food_drop_id = ""
	pulse_scale = 1.0
	_apply_sprite_pose()
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
	pulse_scale = 1.0
	_apply_sprite_pose()
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
	visible_texture_rect = _get_visible_texture_rect(stage_texture)
	visible_texture_center = _get_texture_content_rect().get_center()
	_update_base_scale()


func get_visual_body_size() -> Vector2:
	return visible_texture_rect.size * base_scale


func get_max_animated_body_size() -> Vector2:
	var size: Vector2 = get_visual_body_size() * MAX_EAT_SCALE
	var cosine: float = cos(MAX_SWIM_ROTATION)
	var sine: float = sin(MAX_SWIM_ROTATION)
	return Vector2(size.x * cosine + size.y * sine, size.y * cosine + size.x * sine)


func get_visual_body_rect_global() -> Rect2:
	if sprite.texture == null or visible_texture_rect.size == Vector2.ZERO:
		return Rect2(global_position, Vector2.ZERO)
	var content_rect: Rect2 = _get_texture_content_rect()
	var corners: Array[Vector2] = [
		content_rect.position,
		Vector2(content_rect.end.x, content_rect.position.y),
		Vector2(content_rect.position.x, content_rect.end.y),
		content_rect.end,
	]
	var first: Vector2 = sprite.to_global(corners[0])
	var minimum: Vector2 = first
	var maximum: Vector2 = first
	for corner in corners.slice(1):
		var point: Vector2 = sprite.to_global(corner)
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)
	return Rect2(minimum, maximum - minimum)


func contains_screen_point(screen_position: Vector2, touch_target: float = 56.0) -> bool:
	if sprite.texture == null or not sprite.is_visible_in_tree():
		return false
	var content_rect: Rect2 = _get_texture_content_rect()
	var local_margin: float = touch_target / (2.0 * maxf(base_scale * pulse_scale, 0.001))
	content_rect.position -= Vector2.ONE * local_margin
	content_rect.size += Vector2.ONE * local_margin * 2.0
	return content_rect.has_point(sprite.to_local(screen_position))


func get_distance_to_screen_point(screen_position: Vector2) -> float:
	return sprite.to_global(_get_texture_content_rect().get_center()).distance_to(screen_position)


func _update_base_scale() -> void:
	if not has_water_bounds or visible_texture_rect.size.x <= 0.0 or visible_texture_rect.size.y <= 0.0:
		base_scale = STAGE_ONE_BODY_RATIO
	else:
		var maximum_stage: int = _get_max_stage(current_species_id)
		var progress: float = 0.0
		if maximum_stage > 1:
			progress = float(current_stage - 1) / float(maximum_stage - 1)
		var target_height: float = water_bounds_local.size.y * lerpf(STAGE_ONE_BODY_RATIO, MAX_STAGE_BODY_RATIO, progress)
		var max_width: float = water_bounds_local.size.x * 0.28
		base_scale = minf(target_height / visible_texture_rect.size.y, max_width / visible_texture_rect.size.x)
		base_scale = maxf(base_scale, 0.001)
	_apply_sprite_pose()
	position = _clamp_to_water(position)
	roam_target = _clamp_to_water(roam_target)


func _apply_sprite_pose() -> void:
	if sprite == null or sprite.texture == null:
		return
	var scale_value: float = base_scale * pulse_scale
	sprite.scale = Vector2.ONE * scale_value
	sprite.position = -visible_texture_center * scale_value + Vector2(0.0, bob_offset)


func _get_visible_texture_rect(texture: Texture2D) -> Rect2:
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return Rect2(Vector2.ZERO, Vector2(texture.get_size()))
	var used_rect: Rect2i = image.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		return Rect2(Vector2.ZERO, Vector2(texture.get_size()))
	return Rect2(Vector2(used_rect.position), Vector2(used_rect.size))


func _get_texture_content_rect() -> Rect2:
	if sprite.texture == null:
		return Rect2()
	var origin: Vector2 = sprite.offset
	if sprite.centered:
		origin -= Vector2(sprite.texture.get_size()) * 0.5
	return Rect2(origin + visible_texture_rect.position, visible_texture_rect.size)


func _get_conservative_half_extents() -> Vector2:
	var half_size: Vector2 = get_visual_body_size() * (MAX_EAT_SCALE * 0.5)
	var cosine: float = cos(MAX_SWIM_ROTATION)
	var sine: float = sin(MAX_SWIM_ROTATION)
	return Vector2(
		half_size.x * cosine + half_size.y * sine + 1.0,
		half_size.y * cosine + half_size.x * sine + BOB_AMPLITUDE
	)


func _clamp_to_water(value: Vector2) -> Vector2:
	if not has_water_bounds:
		return value
	var half: Vector2 = _get_conservative_half_extents()
	var center: Vector2 = water_bounds_local.get_center()
	var minimum: Vector2 = Vector2(
		minf(water_bounds_local.position.x + half.x, center.x),
		minf(water_bounds_local.position.y + half.y, center.y)
	)
	var maximum: Vector2 = Vector2(
		maxf(water_bounds_local.end.x - half.x, center.x),
		maxf(water_bounds_local.end.y - half.y, center.y)
	)
	return Vector2(clampf(value.x, minimum.x, maximum.x), clampf(value.y, minimum.y, maximum.y))


func _choose_roam_target() -> void:
	var minimum: Vector2
	var maximum: Vector2
	if has_water_bounds:
		var half: Vector2 = _get_conservative_half_extents()
		var center: Vector2 = water_bounds_local.get_center()
		minimum = Vector2(
			minf(water_bounds_local.position.x + half.x, center.x),
			minf(water_bounds_local.position.y + half.y, center.y)
		)
		maximum = Vector2(
			maxf(water_bounds_local.end.x - half.x, center.x),
			maxf(water_bounds_local.end.y - half.y, center.y)
		)
	else:
		var x_radius: float = float(GameApp.get_balance_value("actor_roam_x_radius", 460.0))
		var y_radius: float = float(GameApp.get_balance_value("actor_roam_y_radius", 150.0))
		minimum = Vector2(-x_radius, -y_radius)
		maximum = Vector2(x_radius, y_radius)
	roam_target = Vector2(rng.randf_range(minimum.x, maximum.x), rng.randf_range(minimum.y, maximum.y))
	var idle_minimum: float = float(GameApp.get_balance_value("actor_roam_idle_min_seconds", 1.5))
	var idle_maximum: float = maxf(idle_minimum, float(GameApp.get_balance_value("actor_roam_idle_max_seconds", 4.0)))
	idle_time = rng.randf_range(idle_minimum, idle_maximum)


func _move_toward(target: Vector2, speed: float, delta: float) -> void:
	var offset: Vector2 = target - position
	if offset.length() > 10.0:
		position = _clamp_to_water(position.move_toward(target, speed * delta))


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
