extends Control

const DOS_STYLE = preload("res://scripts/ui/dos_style.gd")
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
@onready var log_toggle_button: Button = %LogToggleButton
@onready var modal_input_shield: ColorRect = %ModalInputShield
@onready var pet_roster: HBoxContainer = %PetRoster
@onready var pet_roster_backdrop: ColorRect = %PetRosterBackdrop
@onready var status_backdrop: ColorRect = %StatusBackdrop
@onready var top_panel: VBoxContainer = %TopPanel
@onready var inventory_backdrop: ColorRect = %InventoryBackdrop
@onready var action_backdrop: ColorRect = %ActionBackdrop
@onready var action_bar: GridContainer = %ActionBar
@onready var nursery_button: Button = %NurseryButton
@onready var rename_button: Button = %RenameButton
@onready var rename_dialog: ConfirmationDialog = %RenameDialog
@onready var nickname_edit: LineEdit = %NicknameEdit

var passive_timer: float = 0.0
var touch_cooldown: float = 0.0
var touch_status_timer: float = 0.0
var log_next_refresh: bool = false
var sick_generation_notice_shown: bool = false
var last_action_time_by_name: Dictionary = {}
var actors_by_id: Dictionary = {}
var coin_bubbles_by_id: Dictionary = {}
var food_drop_visuals: Dictionary = {}
var food_claims: Dictionary = {}
var roster_buttons_by_id: Dictionary = {}
var food_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var last_world_input_at: int = -1000
var last_world_input_position: Vector2 = Vector2.ZERO
var active_water_rect: Rect2 = Rect2()
var rename_modal_active: bool = false

func _ready() -> void:
	DOS_STYLE.apply(self)
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
	log_toggle_button.pressed.connect(_on_log_toggle_pressed)
	log_toggle_button.visible = OS.is_debug_build()
	runtime_log_panel.visible = false
	shop_panel.visibility_changed.connect(_sync_modal_input_shield)
	nursery_button.pressed.connect(_on_nursery_pressed)
	rename_button.pressed.connect(_on_rename_pressed)
	rename_dialog.confirmed.connect(_on_rename_confirmed)
	rename_dialog.canceled.connect(_close_rename_dialog)
	rename_dialog.close_requested.connect(_close_rename_dialog)
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	FoodDropSystem.expire_due_drops()
	food_rng.randomize()
	_sync_pet_actors()
	_restore_coin_bubbles()
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
	if rename_modal_active or not _accept_action("shop"):
		return
	RuntimeLogger.log_action("Shop clicked")
	_set_shop_open(not shop_panel.visible)


func _set_shop_open(should_open: bool) -> void:
	if should_open:
		runtime_log_panel.visible = false
	shop_panel.visible = should_open
	_sync_modal_input_shield()
	if should_open:
		shop_panel.call("refresh")


func _sync_modal_input_shield() -> void:
	modal_input_shield.visible = shop_panel.visible or rename_modal_active


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
	if rename_modal_active or not OS.is_debug_build() or not _accept_action("log_toggle"):
		return
	var should_show: bool = not runtime_log_panel.visible
	if should_show:
		_set_shop_open(false)
	runtime_log_panel.visible = should_show
	_refresh(false)


func _on_nursery_pressed() -> void:
	if not _select_next_unhatched_egg():
		_show_message("No egg remains in the nursery.")
		return
	SceneRouter.go_hatch()


func _select_next_unhatched_egg() -> bool:
	for egg in GameState.get_nursery_eggs():
		var egg_id: String = str(egg.get("egg_id", ""))
		if not egg_id.is_empty() and GameState.set_active_egg_id(egg_id):
			SaveManager.save_game()
			return true
	return false


func _on_rename_pressed() -> void:
	if shop_panel.visible or rename_modal_active:
		return
	var pet: Dictionary = GameState.get_pet(GameState.get_selected_pet_id())
	if pet.is_empty():
		return
	runtime_log_panel.visible = false
	nickname_edit.text = str(pet.get("nickname", "JellyCat"))
	rename_modal_active = true
	_sync_modal_input_shield()
	rename_dialog.popup_centered(Vector2i(440, 190))
	nickname_edit.grab_focus()


func _close_rename_dialog() -> void:
	rename_modal_active = false
	rename_dialog.hide()
	_sync_modal_input_shield()


func _on_rename_confirmed() -> void:
	_close_rename_dialog()
	var pet_id: String = GameState.get_selected_pet_id()
	var pet: Dictionary = GameState.get_pet(pet_id)
	var nickname: String = nickname_edit.text.strip_edges().left(18)
	if pet.is_empty() or nickname.is_empty():
		_show_message("Enter a name with 1 to 18 characters.")
		return
	if GameState.rename_pet(pet_id, nickname):
		SaveManager.save_game()
		_show_message("Renamed to %s." % nickname)
		_refresh(false)


func _try_spawn_coin_bubble() -> void:
	var active_count: int = CoinDropSystem.get_active_coin_bubble_count(coin_bubble_container)
	if not CoinDropSystem.can_spawn_coin_bubble(active_count):
		return
	var eligible_ids: Array[String] = CoinDropSystem.get_eligible_pet_ids()
	var source_pet_id: String = eligible_ids[food_rng.randi_range(0, eligible_ids.size() - 1)]
	var source_actor: Node2D = actors_by_id.get(source_pet_id) as Node2D
	var source_position: Vector2 = active_water_rect.get_center() if source_actor == null else source_actor.global_position
	var value: int = int(GameApp.get_balance_value("passive_coin_amount", 1))
	var viewport_size: Vector2 = get_viewport_rect().size
	var spawn_position: Vector2 = CoinDropSystem.get_spawn_position(viewport_size, source_position)
	spawn_position = _clamp_to_rect(spawn_position, active_water_rect, 36.0)
	var drop: Dictionary = CoinDropSystem.reserve_coin(source_pet_id, value, spawn_position)
	if drop.is_empty():
		return
	_add_coin_bubble(drop)
	RuntimeLogger.log_info("Bubble coin spawned: +%d" % value)


func _restore_coin_bubbles() -> void:
	for drop in GameState.get_coin_drops():
		_add_coin_bubble(drop)


func _add_coin_bubble(drop: Dictionary) -> void:
	var token_id: String = str(drop.get("token_id", ""))
	if token_id.is_empty() or coin_bubbles_by_id.has(token_id):
		return
	var bubble: Button = COIN_BUBBLE_SCENE.instantiate() as Button
	var visual_drop: Dictionary = drop.duplicate(true)
	var coin_position: Vector2 = Vector2(float(drop.get("x", 0.0)), float(drop.get("y", 0.0)))
	coin_position = _clamp_to_rect(coin_position, active_water_rect, 36.0)
	visual_drop["x"] = coin_position.x
	visual_drop["y"] = coin_position.y
	bubble.call("configure", visual_drop)
	bubble.connect("collected", Callable(self, "_on_coin_bubble_collected"))
	coin_bubble_container.add_child(bubble)
	coin_bubbles_by_id[token_id] = bubble


func _on_coin_bubble_collected(token_id: String, value: int, auto_collected: bool, source_pet_id: String) -> void:
	var drop: Dictionary = CoinDropSystem.collect_coin(token_id, auto_collected)
	var bubble: Node = coin_bubbles_by_id.get(token_id) as Node
	coin_bubbles_by_id.erase(token_id)
	if drop.is_empty():
		if bubble != null:
			bubble.call("discard")
		return
	_show_message("+%d bubble coin · %s" % [value, str(GameState.get_pet(source_pet_id).get("nickname", "JellyCat"))])
	if shop_panel.visible:
		shop_panel.call("refresh")
	_refresh(false)
	if bubble != null:
		bubble.call("animate_to_wallet", coin_label.global_position + coin_label.size / 2.0)


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
		evolution_label.text = "Next stage: Max Stage"
	else:
		var exp_to_next: int = max(0, int(next_stage.get("required_growth_exp", 0)) - growth_exp)
		evolution_label.text = "Next: %s · %d EXP left" % [str(next_stage.get("name", "Next Stage")), exp_to_next]
	_refresh_pet_roster()
	var egg_count: int = GameState.get_nursery_eggs().size()
	nursery_button.text = "Nursery · %d" % egg_count
	nursery_button.disabled = egg_count == 0
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
	var local_water_bounds: Rect2 = Rect2(-active_water_rect.size / 2.0, active_water_rect.size)
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
		actor.call("set_water_bounds", local_water_bounds)
		actors_by_id[pet_id] = actor


func _refresh_pet_roster() -> void:
	var active_ids: Array[String] = GameState.get_active_pet_ids()
	for raw_pet_id in roster_buttons_by_id.keys():
		var pet_id: String = str(raw_pet_id)
		if active_ids.has(pet_id):
			continue
		var old_button: Node = roster_buttons_by_id[raw_pet_id] as Node
		roster_buttons_by_id.erase(raw_pet_id)
		if is_instance_valid(old_button):
			old_button.queue_free()
	for index in range(active_ids.size()):
		var pet_id: String = active_ids[index]
		var button: Button = roster_buttons_by_id.get(pet_id) as Button
		if button == null or not is_instance_valid(button):
			button = Button.new()
			button.toggle_mode = true
			button.custom_minimum_size = Vector2(138.0, 56.0)
			button.pressed.connect(_on_pet_roster_pressed.bind(pet_id))
			pet_roster.add_child(button)
			roster_buttons_by_id[pet_id] = button
		DOS_STYLE.style_button(button)
		var pet: Dictionary = GameState.get_pet(pet_id)
		button.text = "%s · %s" % [str(pet.get("nickname", "JellyCat")), pet_id.trim_prefix("jc_")]
		button.tooltip_text = "Select pet ID %s" % pet_id
		button.button_pressed = pet_id == GameState.get_selected_pet_id()
		pet_roster.move_child(button, index)


func _on_pet_roster_pressed(pet_id: String) -> void:
	if GameState.set_selected_pet_id(pet_id):
		_refresh(false)


func _apply_responsive_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	_layout_ui(viewport_size, _get_safe_viewport_rect(viewport_size))


func _get_safe_viewport_rect(viewport_size: Vector2) -> Rect2:
	var result: Rect2 = Rect2(Vector2.ZERO, viewport_size)
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	var safe_area: Rect2i = DisplayServer.get_display_safe_area()
	if screen_size.x <= 0 or screen_size.y <= 0 or safe_area.size.x <= 0 or safe_area.size.y <= 0:
		return result
	var scale: Vector2 = Vector2(viewport_size.x / float(screen_size.x), viewport_size.y / float(screen_size.y))
	result.position = Vector2(safe_area.position) * scale
	result.size = Vector2(safe_area.size) * scale
	return result


func _layout_ui(viewport_size: Vector2, safe_rect: Rect2) -> void:
	var margin: float = 20.0
	var safe_left: float = maxf(0.0, safe_rect.position.x)
	var safe_top: float = maxf(0.0, safe_rect.position.y)
	var safe_right: float = minf(viewport_size.x, safe_rect.position.x + safe_rect.size.x)
	var safe_bottom: float = minf(viewport_size.y, safe_rect.position.y + safe_rect.size.y)
	var safe_width: float = maxf(1.0, safe_right - safe_left)
	var safe_height: float = maxf(1.0, safe_bottom - safe_top)
	var left_width: float = clampf(safe_width * 0.28, 240.0, 460.0)
	var right_width: float = clampf(safe_width * 0.19, 220.0, 340.0)
	var top_y: float = safe_top + margin
	var status_rect: Rect2 = Rect2(Vector2(safe_left + margin, top_y + 80.0), Vector2(left_width, 308.0))
	_place_control(status_backdrop, status_rect)
	_place_control(top_panel, Rect2(status_rect.position + Vector2(12.0, 8.0), status_rect.size - Vector2(24.0, 16.0)))
	var inventory_rect: Rect2 = Rect2(Vector2(safe_right - margin - right_width, top_y + 80.0), Vector2(right_width, 126.0))
	_place_control(inventory_backdrop, inventory_rect)
	_place_control(inventory_label, Rect2(inventory_rect.position + Vector2(16.0, 12.0), inventory_rect.size - Vector2(32.0, 24.0)))
	var roster_left: float = safe_left + margin
	var roster_right: float = safe_right - margin
	_place_control(pet_roster, Rect2(Vector2(roster_left, top_y + 4.0), Vector2(maxf(0.0, roster_right - roster_left), 64.0)))
	_place_control(pet_roster_backdrop, Rect2(pet_roster.position - Vector2(8.0, 4.0), pet_roster.size + Vector2(16.0, 8.0)))
	var touch_target: float = DOS_STYLE.get_touch_target_height(viewport_size)
	var action_width: float = minf(380.0, maxf(touch_target * 2.0 + 28.0, safe_width * 0.24))
	var action_rows: int = int(ceil(float(action_bar.get_child_count()) / 2.0))
	var action_height: float = minf(action_rows * touch_target + maxf(0.0, action_rows - 1) * 12.0 + 16.0, maxf(1.0, safe_height - margin * 2.0))
	var action_rect: Rect2 = Rect2(Vector2(safe_right - margin - action_width + 8.0, safe_bottom - margin - action_height + 8.0), Vector2(action_width - 16.0, action_height - 16.0))
	_place_control(action_bar, action_rect)
	var button_width: float = maxf(touch_target, (action_bar.size.x - 12.0) / 2.0)
	for child in action_bar.get_children():
		if child is Button:
			(child as Button).custom_minimum_size = Vector2(button_width, touch_target)
	_place_control(action_backdrop, Rect2(action_bar.position - Vector2(8.0, 8.0), action_bar.size + Vector2(16.0, 16.0)))
	var log_width: float = minf(360.0, maxf(320.0, safe_width * 0.28))
	var log_height: float = minf(280.0, maxf(180.0, safe_height - margin * 2.0))
	runtime_log_panel.custom_minimum_size = Vector2(log_width, log_height)
	_place_control(runtime_log_panel, Rect2(Vector2(safe_left + margin, safe_bottom - margin - log_height), Vector2(log_width, log_height)))
	var shop_width: float = minf(360.0, maxf(320.0, safe_width * 0.34))
	var shop_height: float = maxf(220.0, shop_panel.get_combined_minimum_size().y)
	shop_panel.custom_minimum_size = Vector2(shop_width, shop_height)
	_place_control(shop_panel, Rect2(Vector2(safe_left + margin, minf(top_y + 416.0, safe_bottom - margin - shop_height)), Vector2(shop_width, shop_height)))
	var message_left: float = safe_left + margin + left_width + margin
	var message_right: float = safe_right - margin - right_width - margin
	_place_control(message_label, Rect2(Vector2(message_left, top_y + 76.0), Vector2(maxf(0.0, message_right - message_left), 38.0)))
	var left_reserved: float = maxf(left_width, maxf(log_width, shop_width))
	var right_reserved: float = maxf(right_width, action_width)
	var water_left: float = safe_left + margin + left_reserved + margin
	var water_right: float = safe_right - margin - right_reserved - margin
	var water_top: float = maxf(pet_roster_backdrop.position.y + pet_roster_backdrop.size.y, message_label.position.y + message_label.size.y) + margin * 0.5
	var water_bottom: float = safe_bottom - margin
	active_water_rect = Rect2(Vector2(water_left, water_top), Vector2(maxf(1.0, water_right - water_left), maxf(1.0, water_bottom - water_top)))
	actor_anchor.position = active_water_rect.get_center()
	var local_water_bounds: Rect2 = Rect2(-active_water_rect.size / 2.0, active_water_rect.size)
	for actor_value in actors_by_id.values():
		var actor: Node = actor_value as Node
		if is_instance_valid(actor):
			actor.call("set_water_bounds", local_water_bounds)


func _place_control(control: Control, target_rect: Rect2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = target_rect.position
	control.size = target_rect.size


func _actor_spawn_position(index: int, count: int) -> Vector2:
	if count <= 1:
		return Vector2.ZERO
	var spacing: float = active_water_rect.size.x * 0.64 / float(count - 1)
	return Vector2((float(index) - float(count - 1) / 2.0) * spacing, 0.0)


func _has_sick_active_pet() -> bool:
	for pet_id in GameState.get_active_pet_ids():
		if str(GameState.get_pet(pet_id).get("health", "healthy")) == "sick":
			return true
	return false


func _drop_basic_food(screen_position: Vector2) -> void:
	screen_position = _clamp_to_rect(screen_position, active_water_rect, 24.0)
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
			food.position = _clamp_to_rect(Vector2(float(drop.get("x", 0.0)), float(drop.get("y", 0.0))), active_water_rect, 24.0)
			food.mouse_filter = Control.MOUSE_FILTER_IGNORE
			food.add_theme_font_size_override("font_size", 38)
			food.add_theme_color_override("font_color", Color(1.0, 0.91, 0.57, 1.0))
			food.add_theme_color_override("font_outline_color", Color(0.15, 0.1, 0.12, 0.9))
			food.add_theme_constant_override("outline_size", 5)
			food_drop_container.add_child(food)
			food_drop_visuals[token_id] = food
		var visual: Label = food_drop_visuals[token_id] as Label
		visual.position = _clamp_to_rect(visual.position, active_water_rect, 24.0)
		var floor_y: float = active_water_rect.end.y - 24.0
		if visual.position.y < floor_y:
			visual.position.y = minf(floor_y, visual.position.y + float(GameApp.get_balance_value("food_sink_speed", 18.0)) * delta)

	for token_id in food_drop_visuals.keys():
		if drops_by_token.has(str(token_id)):
			continue
		var stale_visual: Node = food_drop_visuals[token_id] as Node
		food_drop_visuals.erase(token_id)
		if is_instance_valid(stale_visual):
			stale_visual.queue_free()

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
	if modal_input_shield.visible:
		return
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
	if not _get_safe_viewport_rect(get_viewport_rect().size).has_point(screen_position) or not active_water_rect.has_point(screen_position):
		return
	var now: int = Time.get_ticks_msec()
	if now - last_world_input_at < 80 and screen_position.distance_to(last_world_input_position) < 2.0:
		return
	last_world_input_at = now
	last_world_input_position = screen_position
	var touch_target: float = DOS_STYLE.get_touch_target_height(get_viewport_rect().size)
	var selected_actor: Node2D = null
	var closest_distance: float = INF
	for pet_id in GameState.get_active_pet_ids():
		var actor: Node2D = actors_by_id.get(pet_id) as Node2D
		if actor == null or not bool(actor.call("contains_screen_point", screen_position, touch_target)):
			continue
		var distance: float = float(actor.call("get_distance_to_screen_point", screen_position))
		if distance < closest_distance:
			closest_distance = distance
			selected_actor = actor
	if selected_actor != null:
		GameState.set_selected_pet_id(str(selected_actor.get("pet_id")))
		selected_actor.call("react_to_touch")
		return
	_drop_basic_food(screen_position)


func _clamp_to_rect(value: Vector2, rect: Rect2, margin: float) -> Vector2:
	var horizontal_margin: float = minf(margin, rect.size.x * 0.5)
	var vertical_margin: float = minf(margin, rect.size.y * 0.5)
	return Vector2(
		clampf(value.x, rect.position.x + horizontal_margin, rect.end.x - horizontal_margin),
		clampf(value.y, rect.position.y + vertical_margin, rect.end.y - vertical_margin)
	)
