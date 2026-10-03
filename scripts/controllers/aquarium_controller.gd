extends Control

const COIN_BUBBLE_SCENE: PackedScene = preload("res://scenes/ui/coin_bubble_pickup.tscn")
const JELLYCAT_ACTOR_SCENE: PackedScene = preload("res://scenes/pet/jellycat_actor.tscn")
const DEFAULT_TOUCH_COOLDOWN_SECONDS: float = 0.5
const ACTION_DEBOUNCE_SECONDS: float = 0.3

@onready var coin_label: Label = %CoinLabel
@onready var stage_label: Label = %StageLabel
@onready var hunger_label: Label = %HungerLabel
@onready var hunger_bar: ProgressBar = %HungerBar
@onready var mood_label: Label = %MoodLabel
@onready var mood_bar: ProgressBar = %MoodBar
@onready var cleanliness_label: Label = %CleanlinessLabel
@onready var clean_bar: ProgressBar = %CleanBar
@onready var health_label: Label = %HealthLabel
@onready var exp_label: Label = %ExpLabel
@onready var touch_exp_label: Label = %TouchExpLabel
@onready var evolution_label: Label = %EvolutionLabel
@onready var inventory_label: Label = %InventoryLabel
@onready var message_label: Label = %MessageLabel
@onready var actor_anchor: Node2D = %ActorAnchor
@onready var food_drop_container: Control = %FoodDropContainer
@onready var shop_panel: Control = %ShopPanel
@onready var coin_bubble_container: Control = %CoinBubbleContainer
@onready var runtime_log_panel: Control = %RuntimeLogPanel

var passive_timer: float = 0.0
var touch_cooldown: float = 0.0
var touch_status_timer: float = 0.0
var log_next_refresh: bool = false
var sick_generation_notice_shown: bool = false
var last_action_time_by_name: Dictionary = {}
var actors_by_id: Dictionary = {}
var food_drop_visuals: Dictionary = {}
var food_claims: Dictionary = {}
var food_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var last_world_input_at: int = -1000
var last_world_input_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	RuntimeLogger.log_info("Aquarium entered")
	GameState.state_changed.connect(_on_state_changed)
	%FeedButton.pressed.connect(_on_feed_pressed)
	%CookieButton.pressed.connect(_on_cookie_pressed)
	%TouchButton.pressed.connect(_on_touch_pressed)
	%CleanButton.pressed.connect(_on_clean_pressed)
	%MedicineButton.pressed.connect(_on_medicine_pressed)
	%EvolveButton.pressed.connect(_on_evolve_pressed)
	%ShopButton.pressed.connect(_on_shop_pressed)
	%DailyFoodButton.pressed.connect(_on_daily_food_pressed)
	%LogToggleButton.pressed.connect(_on_log_toggle_pressed)
	FoodDropSystem.expire_due_drops()
	food_rng.randomize()
	_sync_pet_actors()
	_refresh(true)
	if _has_sick_active_pet():
		RuntimeLogger.log_info("JellyCat is sick, bubble coin generation paused")
		sick_generation_notice_shown = true


func _process(delta: float) -> void:
	_update_food_drops(delta)
	if touch_cooldown > 0.0:
		touch_cooldown = max(0.0, touch_cooldown - delta)
	touch_status_timer += delta
	if touch_status_timer >= 1.0:
		touch_status_timer = 0.0
		_refresh_touch_exp_label()
	passive_timer += delta
	var passive_interval: float = float(GameApp.get_balance_value("passive_coin_interval_seconds", 30))
	if passive_timer >= passive_interval:
		passive_timer = 0.0
		_try_spawn_coin_bubble()


func _on_feed_pressed() -> void:
	if not _accept_action("feed"):
		return
	var selected_actor: Node2D = actors_by_id.get(GameState.get_selected_pet_id()) as Node2D
	var drop_position: Vector2 = actor_anchor.global_position if selected_actor == null else selected_actor.global_position + Vector2(150.0, -70.0)
	_drop_basic_food(drop_position)


func _on_cookie_pressed() -> void:
	if not _accept_action("cookie"):
		return
	if GameState.get_inventory_count("cookie_basic") <= 0:
		_show_result(CareSystem.feed_cookie(GameState.get_selected_pet_id()), "Fed cookie.", "Not enough cookie.", false)
		return
	RuntimeLogger.log_action("Feed cookie clicked")
	_show_result(CareSystem.feed_cookie(GameState.get_selected_pet_id()), "Fed cookie.", "Not enough cookie.", false)


func _on_touch_pressed() -> void:
	if not _accept_action("touch"):
		return
	if touch_cooldown > 0.0:
		return
	var ok: bool = CareSystem.touch_pet(GameState.get_selected_pet_id())
	if ok:
		touch_cooldown = float(GameApp.get_balance_value("touch_cooldown_seconds", DEFAULT_TOUCH_COOLDOWN_SECONDS))
		var actor: Node = actors_by_id.get(GameState.get_selected_pet_id()) as Node
		if actor != null:
			actor.call("react_to_touch")
	_show_result(ok, "JellyCat feels happy.", "Touch cooling down.", false, false)


func _on_clean_pressed() -> void:
	if not _accept_action("clean"):
		return
	var aquarium: Dictionary = GameState.get_aquarium()
	var target_cleanliness: int = int(GameApp.get_balance_value("cleanliness_after_clean", 100))
	if int(aquarium.get("cleanliness", 0)) >= target_cleanliness:
		_show_result(CareSystem.clean_tank(), "Tank cleaned.", "Tank is already clean.", true)
		return
	RuntimeLogger.log_action("Clean clicked")
	_show_result(CareSystem.clean_tank(), "Tank cleaned.", "Tank is already clean.", true)


func _on_medicine_pressed() -> void:
	if not _accept_action("medicine"):
		return
	var pet_id: String = GameState.get_selected_pet_id()
	var pet: Dictionary = GameState.get_pet(pet_id)
	if pet.is_empty() or str(pet.get("health", "healthy")) == "healthy" or GameState.get_inventory_count("medicine_basic") <= 0:
		_show_result(CareSystem.give_medicine(pet_id), "Medicine used.", "No medicine or no pet selected.", true)
		return
	RuntimeLogger.log_action("Medicine clicked")
	_show_result(CareSystem.give_medicine(pet_id), "Medicine used.", "No medicine or no pet selected.", true)


func _on_evolve_pressed() -> void:
	if not _accept_action("evolve"):
		return
	var pet_id: String = GameState.get_selected_pet_id()
	var pet: Dictionary = GameState.get_pet(pet_id)
	var failure_message: String = "Cannot evolve yet."
	var next_stage: Dictionary = EvolutionSystem.get_next_stage_data(pet_id)
	if next_stage.is_empty():
		failure_message = "Already max stage or no pet selected."
		_show_result(EvolutionSystem.evolve(pet_id), "JellyCat evolved.", failure_message, true)
		return
	if pet.is_empty() or int(pet.get("growth_exp", 0)) < int(next_stage.get("required_growth_exp", 0)):
		_show_result(EvolutionSystem.evolve(pet_id), "JellyCat evolved.", failure_message, true)
		return
	RuntimeLogger.log_action("Evolve clicked")
	var ok: bool = EvolutionSystem.evolve(pet_id)
	_show_result(ok, "JellyCat evolved.", failure_message, true)


func _on_shop_pressed() -> void:
	if not _accept_action("shop"):
		return
	RuntimeLogger.log_action("Shop clicked")
	shop_panel.visible = not shop_panel.visible
	if shop_panel.visible:
		shop_panel.call("refresh")


func _on_daily_food_pressed() -> void:
	if not _accept_action("daily_food"):
		return
	var today: String = _today_string()
	var daily_claim: Dictionary = GameState.get_daily_claim()
	if str(daily_claim.get("last_free_food_date", "")) == today:
		RuntimeLogger.log_info_throttled("daily_free_food_already_claimed", "Daily free food already claimed")
		_show_message("Daily free food already claimed.")
		return
	var old_count: int = GameState.get_inventory_count("food_basic")
	GameState.set_inventory_count("food_basic", old_count + 1)
	daily_claim["last_free_food_date"] = today
	GameState.set_daily_claim(daily_claim)
	RuntimeLogger.log_action("Daily free food claimed")
	RuntimeLogger.log_state("inventory food_basic changed: %d -> %d" % [old_count, GameState.get_inventory_count("food_basic")])
	_show_message("Daily free food claimed.")
	_refresh(false)


func _on_log_toggle_pressed() -> void:
	if not _accept_action("log_toggle"):
		return
	runtime_log_panel.visible = not runtime_log_panel.visible
	_refresh(false)


func _try_spawn_coin_bubble() -> void:
	var active_count: int = CoinDropSystem.get_active_coin_bubble_count(coin_bubble_container)
	if _has_sick_active_pet():
		if not sick_generation_notice_shown:
			RuntimeLogger.log_info("JellyCat is sick, bubble coin generation paused")
			sick_generation_notice_shown = true
		return
	if not CoinDropSystem.can_spawn_coin_bubble(active_count):
		return
	sick_generation_notice_shown = false
	var value: int = int(GameApp.get_balance_value("passive_coin_amount", 1))
	var bubble: Button = COIN_BUBBLE_SCENE.instantiate() as Button
	bubble.set("value", value)
	bubble.set("auto_collect_seconds", float(GameApp.get_balance_value("coin_bubble_auto_collect_seconds", 15)))
	var spawn_position: Vector2 = CoinDropSystem.get_spawn_position(get_viewport_rect().size)
	bubble.position = spawn_position - Vector2(36, 36)
	bubble.connect("collected", Callable(self, "_on_coin_bubble_collected"))
	coin_bubble_container.add_child(bubble)
	RuntimeLogger.log_info("Bubble coin spawned: +%d" % value)


func _on_coin_bubble_collected(value: int, auto_collected: bool) -> void:
	CoinDropSystem.collect_coin(value, auto_collected)
	_show_message("+%d bubble coin" % value)
	if shop_panel.visible:
		shop_panel.call("refresh")
	_refresh(false)


func _show_result(ok: bool, success: String, failure: String, immediate_save: bool, log_refresh: bool = true) -> void:
	if ok:
		_show_message(success)
	else:
		_show_message(failure)
		return
	if ok and immediate_save:
		SaveManager.save_game()
	_refresh(log_refresh)


func _show_message(text: String) -> void:
	message_label.text = text


func _on_state_changed() -> void:
	_sync_pet_actors()
	_refresh(false)


func _refresh(log_refresh: bool = false) -> void:
	var pet_id: String = GameState.get_selected_pet_id()
	var jellycat: Dictionary = GameState.get_pet(pet_id)
	if jellycat.is_empty():
		RuntimeLogger.log_error("No jellycat found")
		return
	var stage_data: Dictionary = EvolutionSystem.get_current_stage_data(pet_id)
	var next_stage: Dictionary = EvolutionSystem.get_next_stage_data(pet_id)
	var hunger_value: int = int(jellycat.get("hunger", 0))
	var mood_value: int = int(jellycat.get("mood", 0))
	var cleanliness_value: int = int(GameState.get_aquarium().get("cleanliness", 100))
	var growth_exp: int = int(jellycat.get("growth_exp", 0))
	coin_label.text = "Bubble Coin: %d" % GameState.get_currency("bubble_coin")
	stage_label.text = "%s  Stage %d · %s" % [str(jellycat.get("nickname", "JellyCat")), int(jellycat.get("stage", 1)), str(stage_data.get("name", ""))]
	hunger_label.text = "Hunger: %d / 100" % hunger_value
	mood_label.text = "Mood: %d / 100" % mood_value
	cleanliness_label.text = "Cleanliness: %d / 100" % cleanliness_value
	hunger_bar.value = hunger_value
	mood_bar.value = mood_value
	clean_bar.value = cleanliness_value
	health_label.text = "Health: %s" % str(jellycat.get("health", "healthy"))
	exp_label.text = "Growth EXP: %d" % growth_exp
	_refresh_touch_exp_label()
	inventory_label.text = "Food x%d\nCookie x%d\nMedicine x%d" % [
		GameState.get_inventory_count("food_basic"),
		GameState.get_inventory_count("cookie_basic"),
		GameState.get_inventory_count("medicine_basic")
	]
	if next_stage.is_empty():
		evolution_label.text = "Evolution: Max Stage"
	else:
		evolution_label.text = "Evolution: %d / %d  Next: %s" % [
			growth_exp,
			int(next_stage.get("required_growth_exp", 0)),
			next_stage.get("name", "Next Stage")
		]
	for actor_id in actors_by_id.keys():
		var actor: Node = actors_by_id[actor_id] as Node
		if is_instance_valid(actor):
			actor.call("refresh_pet")
	if runtime_log_panel.visible:
		%LogToggleButton.text = "Hide Log"
	else:
		%LogToggleButton.text = "Show Log"
	if log_refresh:
		RuntimeLogger.log_info("Aquarium UI refreshed")


func _today_string() -> String:
	var date: Dictionary = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(date.get("year", 0)), int(date.get("month", 0)), int(date.get("day", 0))]


func _refresh_touch_exp_label() -> void:
	var care_stats: Dictionary = GameState.get_current_care_stats(GameState.get_selected_pet_id())
	var touch_cap: int = int(GameApp.get_balance_value("touch_growth_exp_cap", 20))
	var reset_seconds: float = max(float(GameApp.get_balance_value("touch_exp_reset_seconds", 600)), 1.0)
	var raw_start: String = str(care_stats.get("touch_exp_date", ""))
	var started_at: float = raw_start.to_float() if raw_start.is_valid_float() else 0.0
	var elapsed: float = Time.get_unix_time_from_system() - started_at
	if started_at <= 0.0 or elapsed < 0.0 or elapsed >= reset_seconds:
		touch_exp_label.text = "Touch EXP: 0/%d | Ready" % touch_cap
		return
	var remaining: int = int(ceil(reset_seconds - elapsed))
	touch_exp_label.text = "Touch EXP: %d/%d | Reset %02d:%02d" % [
		int(care_stats.get("touch_growth_exp_today", 0)),
		touch_cap,
		remaining / 60,
		remaining % 60
	]


func _accept_action(action_name: String) -> bool:
	var now: float = Time.get_ticks_msec() / 1000.0
	var last: float = float(last_action_time_by_name.get(action_name, -999999.0))
	if now - last < ACTION_DEBOUNCE_SECONDS:
		return false
	last_action_time_by_name[action_name] = now
	return true


func _sync_pet_actors() -> void:
	var active_ids: Array[String] = GameState.get_active_pet_ids()
	for pet_id in actors_by_id.keys():
		if not active_ids.has(str(pet_id)):
			var old_actor: Node = actors_by_id[pet_id] as Node
			if is_instance_valid(old_actor):
				old_actor.queue_free()
			actors_by_id.erase(pet_id)
	for index in range(active_ids.size()):
		var pet_id: String = active_ids[index]
		if actors_by_id.has(pet_id):
			continue
		var actor: Node2D = JELLYCAT_ACTOR_SCENE.instantiate() as Node2D
		if actor == null or not bool(actor.call("set_pet_id", pet_id)):
			if actor != null:
				actor.free()
			push_error("Aquarium rejected actor binding for pet_id: %s" % pet_id)
			continue
		actor.position = _actor_spawn_position(index, active_ids.size())
		actor.connect("food_eaten", Callable(self, "_on_actor_food_eaten"))
		actor_anchor.add_child(actor)
		actors_by_id[pet_id] = actor


func _actor_spawn_position(index: int, count: int) -> Vector2:
	return Vector2((float(index) - float(count - 1) / 2.0) * 220.0, 0.0)


func _has_sick_active_pet() -> bool:
	for pet_id in GameState.get_active_pet_ids():
		if str(GameState.get_pet(pet_id).get("health", "healthy")) == "sick":
			return true
	return false


func _drop_basic_food(screen_position: Vector2) -> void:
	var drop: Dictionary = FoodDropSystem.drop_food(screen_position)
	if drop.is_empty():
		_show_message("No basic food available.")
		return
	RuntimeLogger.log_action("Basic food dropped: %s" % str(drop.get("token_id", "")))
	_show_message("Food is sinking.")


func _update_food_drops(delta: float) -> void:
	FoodDropSystem.expire_due_drops()
	var drops: Array[Dictionary] = GameState.get_food_drops()
	var drops_by_token: Dictionary = {}
	for drop in drops:
		var token_id: String = str(drop.get("token_id", ""))
		drops_by_token[token_id] = drop
		if not food_drop_visuals.has(token_id):
			var food: Label = Label.new()
			food.text = "●"
			food.position = Vector2(float(drop.get("x", 0.0)), float(drop.get("y", 0.0)))
			food.mouse_filter = Control.MOUSE_FILTER_IGNORE
			food.add_theme_font_size_override("font_size", 38)
			food.add_theme_color_override("font_color", Color(1.0, 0.91, 0.57, 1.0))
			food.add_theme_color_override("font_outline_color", Color(0.15, 0.1, 0.12, 0.9))
			food.add_theme_constant_override("outline_size", 5)
			food_drop_container.add_child(food)
			food_drop_visuals[token_id] = food
		var visual: Label = food_drop_visuals[token_id] as Label
		var floor_y: float = get_viewport_rect().size.y - 150.0
		if visual.position.y < floor_y:
			visual.position.y = minf(floor_y, visual.position.y + float(GameApp.get_balance_value("food_sink_speed", 18.0)) * delta)

	for token_id in food_claims.keys():
		if not drops_by_token.has(str(token_id)):
			var former_pet_id: String = str(food_claims[token_id])
			var former_actor: Node = actors_by_id.get(former_pet_id) as Node
			if former_actor != null:
				former_actor.call("clear_food_target", str(token_id))
			food_claims.erase(token_id)

	var occupied_pet_ids: Dictionary = {}
	for token_id in food_claims.keys():
		occupied_pet_ids[str(food_claims[token_id])] = true
	for drop in drops:
		var token_id: String = str(drop.get("token_id", ""))
		if food_claims.has(token_id):
			continue
		var pet_id: String = _choose_food_pet(occupied_pet_ids)
		if pet_id.is_empty():
			continue
		food_claims[token_id] = pet_id
		occupied_pet_ids[pet_id] = true

	var eat_radius: float = float(GameApp.get_balance_value("food_eat_radius", 64.0))
	for token_id in food_claims.keys():
		var pet_id: String = str(food_claims[token_id])
		var actor: Node2D = actors_by_id.get(pet_id) as Node2D
		var visual: Label = food_drop_visuals.get(token_id) as Label
		if actor == null or visual == null or not actor.call("can_accept_food"):
			continue
		var target_position: Vector2 = actor_anchor.to_local(visual.global_position + visual.size / 2.0)
		actor.call("set_food_target", str(token_id), target_position)
		if actor.position.distance_to(target_position) <= eat_radius:
			actor.call("begin_eating", str(token_id))


func _choose_food_pet(occupied_pet_ids: Dictionary) -> String:
	var lowest_hunger: int = 101
	var candidates: Array[String] = []
	for pet_id in GameState.get_active_pet_ids():
		if occupied_pet_ids.has(pet_id):
			continue
		var actor: Node = actors_by_id.get(pet_id) as Node
		var pet: Dictionary = GameState.get_pet(pet_id)
		var hunger: int = int(pet.get("hunger", 100))
		if actor == null or not bool(actor.call("can_accept_food")) or hunger >= 95:
			continue
		if hunger < lowest_hunger:
			lowest_hunger = hunger
			candidates.clear()
		candidates.append(pet_id)
	if candidates.is_empty():
		return ""
	return candidates[food_rng.randi_range(0, candidates.size() - 1)]


func _on_actor_food_eaten(token_id: String, pet_id: String) -> void:
	var actor: Node = actors_by_id.get(pet_id) as Node
	var success: bool = FoodDropSystem.consume_food(token_id, pet_id)
	food_claims.erase(token_id)
	var visual: Node = food_drop_visuals.get(token_id) as Node
	food_drop_visuals.erase(token_id)
	if is_instance_valid(visual):
		visual.queue_free()
	if actor == null:
		return
	if success:
		actor.call("complete_meal", token_id)
		_show_message("%s ate." % str(GameState.get_pet(pet_id).get("nickname", "JellyCat")))
	else:
		actor.call("clear_food_target", token_id)


func _unhandled_input(event: InputEvent) -> void:
	var screen_position: Vector2
	if event is InputEventScreenTouch:
		if not (event as InputEventScreenTouch).pressed:
			return
		screen_position = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		screen_position = mouse_event.position
	else:
		return
	var now: int = Time.get_ticks_msec()
	if now - last_world_input_at < 80 and screen_position.distance_to(last_world_input_position) < 2.0:
		return
	last_world_input_at = now
	last_world_input_position = screen_position
	for pet_id in GameState.get_active_pet_ids():
		var actor: Node2D = actors_by_id.get(pet_id) as Node2D
		if actor != null and screen_position.distance_to(actor.global_position) <= 110.0:
			GameState.set_selected_pet_id(pet_id)
			actor.call("react_to_touch")
			return
	_drop_basic_food(screen_position)
