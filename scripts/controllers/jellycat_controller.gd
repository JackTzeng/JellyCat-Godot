extends Node2D

signal food_eaten(token_id: String, pet_id: String)
signal food_refused(token_id: String, pet_id: String)

const DEFAULT_SPECIES_ID: String = "normal_jellycat"
const DEFAULT_MAX_STAGE: int = 5
const STAGE_TEXTURE_PATH: String = "res://assets/jellycats/%s/stages/stage_%d.png"
const STAGE_ONE_BODY_RATIO: float = 0.18
const MAX_STAGE_BODY_RATIO: float = 0.22
const MAX_EAT_SCALE: float = 1.09
const MAX_SWIM_ROTATION: float = 0.025
const BOB_AMPLITUDE: float = 8.0
const EAT_ANIMATION_SECONDS: float = 0.45
const FULL_FOOD_REFUSAL_SECONDS: float = 0.8
@onready var sprite: Sprite2D = %Sprite

var pet_id: String = ""
var bob_time: float = 0.0
var bob_phase: float = 0.0
var bob_offset: float = 0.0
var idle_time: float = 0.0
var roam_target: Vector2 = Vector2.ZERO
var behavior_state: String = "idle_roam"
var food_drop_id: String = ""
var full_food_drop_id: String = ""
var post_meal_timer: float = 0.0
var touch_reaction_timer: float = 0.0
var eat_elapsed: float = 0.0
var full_food_refusal_timer: float = 0.0
var eat_timer: Timer
var current_stage: int = 0
var current_species_id: String = ""
var base_scale: float = STAGE_ONE_BODY_RATIO
var pulse_scale: float = 1.0
var water_bounds_local: Rect2 = Rect2()
var has_water_bounds: bool = false
var visible_texture_rect: Rect2 = Rect2()
var visible_texture_center: Vector2 = Vector2.ZERO
var layout_transition_active: bool = false
var layout_transition_elapsed: float = 0.0
var layout_transition_duration: float = 0.0
var layout_transition_start_position: Vector2 = Vector2.ZERO
var layout_transition_target_position: Vector2 = Vector2.ZERO
var layout_transition_start_roam_target: Vector2 = Vector2.ZERO
var layout_transition_target_roam_target: Vector2 = Vector2.ZERO
var panel_evasion_active: bool = false
var panel_evasion_target: Vector2 = Vector2.ZERO
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
	if panel_evasion_active:
		position = position.move_toward(
			panel_evasion_target,
			float(GameApp.get_balance_value("actor_swim_speed", 32.0)) * delta
		)
		if position.distance_to(panel_evasion_target) <= 1.0:
			position = panel_evasion_target
			panel_evasion_active = false
	if layout_transition_active:
		_advance_layout_transition(delta)
	else:
		match behavior_state:
			"idle_roam":
				if offset.length() <= 10.0:
					idle_time -= delta
					if idle_time <= 0.0 and not panel_evasion_active:
						_choose_roam_target()
				elif not panel_evasion_active:
					_move_toward(roam_target, float(GameApp.get_balance_value("actor_swim_speed", 32.0)), delta)
			"approach_food":
				if not panel_evasion_active:
					_move_toward(roam_target, float(GameApp.get_balance_value("actor_food_chase_speed", 68.0)), delta)
			"approach_full_food":
				if not panel_evasion_active:
					_move_toward(roam_target, float(GameApp.get_balance_value("actor_food_chase_speed", 68.0)), delta)
				if not panel_evasion_active and position.distance_to(roam_target) <= 10.0:
					_begin_full_food_refusal()
			"eat":
				eat_elapsed = minf(EAT_ANIMATION_SECONDS, eat_elapsed + delta)
			"post_meal":
				post_meal_timer -= delta
				if post_meal_timer <= 0.0:
					_set_behavior_state("idle_roam")
					_choose_roam_target()
			"touch_reaction":
				touch_reaction_timer -= delta
				if touch_reaction_timer <= 0.0:
					_set_behavior_state("idle_roam")
					_choose_roam_target()
			"full_food_refusal":
				full_food_refusal_timer -= delta
				if full_food_refusal_timer <= 0.0:
					full_food_drop_id = ""
					_set_behavior_state("idle_roam")
					_choose_roam_target()
	pulse_scale = 1.0
	if behavior_state == "eat":
		pulse_scale = _get_eat_pulse_scale(eat_elapsed)
	if behavior_state == "idle_roam" or behavior_state == "approach_food":
		sprite.flip_h = offset.x < 0.0
	bob_offset = sin(bob_time * 2.0 + bob_phase) * BOB_AMPLITUDE
	sprite.rotation = sin(bob_time * 1.2 + bob_phase) * MAX_SWIM_ROTATION
	if behavior_state == "full_food_refusal":
		sprite.rotation += sin(bob_time * 30.0) * 0.32
	_apply_sprite_pose()
	if not layout_transition_active and not panel_evasion_active:
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


func update_water_bounds_preserving_position(bounds: Rect2, update_visual_scale: bool = false) -> void:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	water_bounds_local = bounds
	has_water_bounds = true
	layout_transition_active = false
	if update_visual_scale:
		_update_base_scale(false)


func set_layout_water_bounds(
	bounds: Rect2,
	anchor_delta: Vector2,
	transition_seconds: float,
	occupied_positions: Array[Vector2],
	touch_target: float
) -> Vector2:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return position
	var previous_bounds: Rect2 = water_bounds_local
	var previously_had_bounds: bool = has_water_bounds
	var bounds_changed: bool = not previously_had_bounds or previous_bounds.position.distance_to(bounds.position) > 0.5 or previous_bounds.size.distance_to(bounds.size) > 0.5
	var anchor_changed: bool = anchor_delta.length() > 0.5
	if previously_had_bounds and not bounds_changed and not anchor_changed:
		return layout_transition_target_position if layout_transition_active else position
	position -= anchor_delta
	roam_target -= anchor_delta
	water_bounds_local = bounds
	has_water_bounds = true
	_update_base_scale(false)
	var body_size: Vector2 = get_visual_body_size()
	var minimum_separation: float = maxf(body_size.x, body_size.y) + touch_target
	var target_position: Vector2 = _find_spaced_layout_position(_clamp_to_water(position), occupied_positions, minimum_separation)
	var target_roam_target: Vector2 = _clamp_to_water(roam_target)
	if behavior_state == "idle_roam":
		target_roam_target = _find_spaced_layout_position(target_roam_target, occupied_positions, minimum_separation)
	var should_animate: bool = transition_seconds > 0.0 and previously_had_bounds and (anchor_changed or bounds_changed)
	if not should_animate:
		layout_transition_active = false
		position = target_position
		roam_target = target_roam_target
		return target_position
	layout_transition_active = true
	layout_transition_elapsed = 0.0
	layout_transition_duration = transition_seconds
	layout_transition_start_position = position
	layout_transition_target_position = target_position
	layout_transition_start_roam_target = roam_target
	layout_transition_target_roam_target = target_roam_target
	return target_position


func _advance_layout_transition(delta: float) -> void:
	layout_transition_elapsed = minf(layout_transition_duration, layout_transition_elapsed + delta)
	var progress: float = clampf(layout_transition_elapsed / maxf(layout_transition_duration, 0.001), 0.0, 1.0)
	var eased_progress: float = 1.0 - pow(1.0 - progress, 3.0)
	position = layout_transition_start_position.lerp(layout_transition_target_position, eased_progress)
	roam_target = layout_transition_start_roam_target.lerp(layout_transition_target_roam_target, eased_progress)
	if progress >= 1.0:
		position = layout_transition_target_position
		roam_target = layout_transition_target_roam_target
		layout_transition_active = false


func set_food_target(token_id: String, target_position: Vector2) -> bool:
	if behavior_state in ["post_meal", "touch_reaction", "eat", "approach_full_food", "full_food_refusal"]:
		return false
	food_drop_id = token_id
	if layout_transition_active:
		layout_transition_target_roam_target = _clamp_to_water(target_position)
	else:
		roam_target = _clamp_to_water(target_position)
	_set_behavior_state("approach_food")
	return true


func clear_food_target(token_id: String) -> void:
	if food_drop_id != token_id:
		return
	if eat_timer != null:
		eat_timer.stop()
		eat_timer.queue_free()
		eat_timer = null
	food_drop_id = ""
	eat_elapsed = 0.0
	pulse_scale = 1.0
	_apply_sprite_pose()
	_set_behavior_state("idle_roam")
	_choose_roam_target()


func begin_eating(token_id: String) -> void:
	if food_drop_id != token_id or behavior_state != "approach_food":
		return
	_set_behavior_state("eat")
	eat_elapsed = 0.0
	_play_sheet_effect("res://assets/effects/eat_sheet_3x32.png", 3, 12.0)
	eat_timer = Timer.new()
	eat_timer.one_shot = true
	eat_timer.wait_time = EAT_ANIMATION_SECONDS
	eat_timer.timeout.connect(_on_eat_timer_timeout.bind(token_id))
	add_child(eat_timer)
	eat_timer.start()


func _on_eat_timer_timeout(token_id: String) -> void:
	if eat_timer != null:
		eat_timer.queue_free()
		eat_timer = null
	if is_inside_tree() and behavior_state == "eat" and food_drop_id == token_id:
		food_eaten.emit(token_id, pet_id)


func _get_eat_pulse_scale(elapsed: float) -> float:
	var progress: float = clampf(elapsed / EAT_ANIMATION_SECONDS, 0.0, 1.0)
	if progress < 0.2:
		return lerpf(1.0, 0.82, progress / 0.2)
	if progress < 0.55:
		return lerpf(0.82, 1.09, (progress - 0.2) / 0.35)
	return lerpf(1.09, 1.0, (progress - 0.55) / 0.45)


func complete_meal(token_id: String) -> void:
	if food_drop_id != token_id:
		return
	pulse_scale = 1.0
	_apply_sprite_pose()
	food_drop_id = ""
	_set_behavior_state("post_meal")
	post_meal_timer = float(GameApp.get_balance_value("actor_food_post_meal_seconds", 2.0))
	_choose_roam_target()


func react_to_touch() -> void:
	_update_touch_paw_wave_anchor()
	_play_touch_paw_wave()


func _update_touch_paw_wave_anchor() -> void:
	var anchor: Node2D = get_node_or_null("TouchPawWaveAnchor") as Node2D
	if anchor == null or sprite.texture == null:
		return
	var source_origin: Vector2 = sprite.offset
	if sprite.centered:
		source_origin -= Vector2(sprite.texture.get_size()) * 0.5
	anchor.position = to_local(sprite.to_global(source_origin + Vector2(16.0, -23.0)))


func _play_touch_paw_wave() -> void:
	# ART-HAND-01 v4 is pending Jack's visual approval; keep this playback hook reserved.
	pass


func set_panel_evasion_target(target: Vector2) -> void:
	panel_evasion_active = true
	panel_evasion_target = target


func clear_panel_evasion() -> void:
	panel_evasion_active = false


func is_panel_evasion_active() -> bool:
	return panel_evasion_active


func can_react_to_full_food() -> bool:
	return behavior_state == "idle_roam" or behavior_state == "approach_full_food"


func set_full_food_target(token_id: String, target_position: Vector2) -> bool:
	if token_id.is_empty() or not can_react_to_full_food():
		return false
	full_food_drop_id = token_id
	roam_target = _clamp_to_water(target_position)
	_set_behavior_state("approach_full_food")
	return true


func clear_full_food_target(token_id: String) -> void:
	if full_food_drop_id != token_id:
		return
	full_food_drop_id = ""
	if behavior_state == "approach_full_food":
		_set_behavior_state("idle_roam")
		_choose_roam_target()


func _begin_full_food_refusal() -> void:
	if full_food_drop_id.is_empty() or behavior_state != "approach_full_food":
		return
	_set_behavior_state("full_food_refusal")
	full_food_refusal_timer = FULL_FOOD_REFUSAL_SECONDS
	food_refused.emit(full_food_drop_id, pet_id)


func _set_behavior_state(next_state: String) -> void:
	if behavior_state == next_state:
		return
	var previous_state: String = behavior_state
	behavior_state = next_state
	RuntimeLogger.log_state_throttled(
		"actor_state_%s" % pet_id,
		"%s state %s -> %s" % [pet_id, previous_state, next_state],
		0.25
	)


func _play_sheet_effect(texture_path: String, frame_count: int, fps: float) -> void:
	var sheet: Texture2D = load(texture_path) as Texture2D
	if sheet == null:
		return
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_animation("play")
	frames.set_animation_speed("play", fps)
	frames.set_animation_loop("play", false)
	for frame_index in range(frame_count):
		var frame: AtlasTexture = AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2(Vector2(frame_index * 32, 0), Vector2(32, 32))
		frames.add_frame("play", frame)
	var effect: AnimatedSprite2D = AnimatedSprite2D.new()
	effect.sprite_frames = frames
	effect.animation = "play"
	effect.position = Vector2(0.0, -maxf(get_visual_body_size().y * 0.35, 18.0))
	effect.z_index = 5
	effect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	effect.animation_finished.connect(effect.queue_free)
	add_child(effect)
	effect.play("play")


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


func _update_base_scale(clamp_actor_to_bounds: bool = true) -> void:
	if not has_water_bounds or visible_texture_rect.size.x <= 0.0 or visible_texture_rect.size.y <= 0.0:
		base_scale = STAGE_ONE_BODY_RATIO
	else:
		var maximum_stage: int = _get_max_stage(current_species_id)
		var stage_one_texture: Texture2D = _load_stage_texture(current_species_id, 1)
		var maximum_stage_texture: Texture2D = _load_stage_texture(current_species_id, maximum_stage)
		var stage_one_rect: Rect2 = _get_visible_texture_rect(stage_one_texture) if stage_one_texture != null else visible_texture_rect
		var maximum_stage_rect: Rect2 = _get_visible_texture_rect(maximum_stage_texture) if maximum_stage_texture != null else visible_texture_rect
		var target_scale: float = minf(
			water_bounds_local.size.y * STAGE_ONE_BODY_RATIO / maxf(stage_one_rect.size.y, 1.0),
			water_bounds_local.size.x * 0.28 / maxf(stage_one_rect.size.x, 1.0)
		)
		var integer_scale: int = maxi(1, int(round(target_scale)))
		while integer_scale > 1:
			var maximum_body_size: Vector2 = maximum_stage_rect.size * float(integer_scale) * MAX_EAT_SCALE
			var cosine: float = cos(MAX_SWIM_ROTATION)
			var sine: float = sin(MAX_SWIM_ROTATION)
			var maximum_half_extents: Vector2 = Vector2(
				maximum_body_size.x * 0.5 * cosine + maximum_body_size.y * 0.5 * sine + 1.0,
				maximum_body_size.y * 0.5 * cosine + maximum_body_size.x * 0.5 * sine + BOB_AMPLITUDE
			)
			if maximum_half_extents.x * 2.0 <= water_bounds_local.size.x and maximum_half_extents.y * 2.0 <= water_bounds_local.size.y:
				break
			integer_scale -= 1
		base_scale = float(integer_scale)
	_apply_sprite_pose()
	if clamp_actor_to_bounds:
		position = _clamp_to_water(position)
		roam_target = _clamp_to_water(roam_target)


func _apply_sprite_pose() -> void:
	if sprite == null or sprite.texture == null:
		return
	var scale_value: float = base_scale * pulse_scale
	sprite.scale = Vector2.ONE * scale_value
	sprite.position = -visible_texture_center * scale_value + Vector2(0.0, bob_offset)
	_update_touch_paw_wave_anchor()


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
	var center_bounds: Rect2 = _get_water_center_bounds()
	return Vector2(
		clampf(value.x, center_bounds.position.x, center_bounds.end.x),
		clampf(value.y, center_bounds.position.y, center_bounds.end.y)
	)


func _get_water_center_bounds() -> Rect2:
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
	return Rect2(minimum, maximum - minimum)


func _find_spaced_layout_position(preferred: Vector2, occupied_positions: Array[Vector2], minimum_separation: float) -> Vector2:
	if occupied_positions.is_empty() or minimum_separation <= 0.0:
		return preferred
	var nearest_clearance: float = INF
	for occupied_position in occupied_positions:
		nearest_clearance = minf(nearest_clearance, preferred.distance_to(occupied_position))
	if nearest_clearance >= minimum_separation:
		return preferred
	var center_bounds: Rect2 = _get_water_center_bounds()
	var step: float = maxf(minimum_separation * 0.5, 16.0)
	var x_positions: Array[float] = [center_bounds.position.x, center_bounds.end.x, center_bounds.get_center().x, clampf(preferred.x, center_bounds.position.x, center_bounds.end.x)]
	var y_positions: Array[float] = [center_bounds.position.y, center_bounds.end.y, center_bounds.get_center().y, clampf(preferred.y, center_bounds.position.y, center_bounds.end.y)]
	var cursor: float = center_bounds.position.x
	while cursor < center_bounds.end.x:
		x_positions.append(cursor)
		cursor += step
	cursor = center_bounds.position.y
	while cursor < center_bounds.end.y:
		y_positions.append(cursor)
		cursor += step
	var best_open_position: Vector2 = preferred
	var best_open_distance: float = INF
	var found_open_position: bool = false
	var best_clearance_position: Vector2 = preferred
	var best_clearance: float = -INF
	var best_fallback_distance: float = INF
	for y in y_positions:
		for x in x_positions:
			var candidate: Vector2 = Vector2(x, y)
			var clearance: float = INF
			for occupied_position in occupied_positions:
				clearance = minf(clearance, candidate.distance_to(occupied_position))
			var candidate_distance: float = candidate.distance_to(preferred)
			if clearance >= minimum_separation and candidate_distance < best_open_distance:
				best_open_position = candidate
				best_open_distance = candidate_distance
				found_open_position = true
			if clearance > best_clearance or (is_equal_approx(clearance, best_clearance) and candidate_distance < best_fallback_distance):
				best_clearance_position = candidate
				best_clearance = clearance
				best_fallback_distance = candidate_distance
	return best_open_position if found_open_position else best_clearance_position


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
