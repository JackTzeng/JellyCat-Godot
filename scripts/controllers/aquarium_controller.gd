extends Control

const DOS_STYLE = preload("res://scripts/ui/dos_style.gd")
const NATIVE_TEXT_ENTRY = preload("res://scripts/ui/native_text_entry.gd")
const COIN_BUBBLE_SCENE: PackedScene = preload("res://scenes/ui/coin_bubble_pickup.tscn")
const JELLYCAT_ACTOR_SCENE: PackedScene = preload("res://scenes/pet/jellycat_actor.tscn")
const DEFAULT_TOUCH_COOLDOWN_SECONDS: float = 0.5
const ACTION_DEBOUNCE_SECONDS: float = 0.3
const WORLD_INPUT_PAIR_DEBOUNCE_MSEC: int = 250
const LAYOUT_TRANSITION_SECONDS: float = 0.32
const FOOD_INTERACTION_SIZE: Vector2 = Vector2(32.0, 32.0)
const FOOD_DISPLAY_SIZE: Vector2 = Vector2(64.0, 64.0)
const FOOD_SUNK_CLEANUP_MSEC: int = 3000
const FOOD_EAT_ANIMATION_SECONDS: float = 0.45
const PET_SLOT_COUNT: int = 3
const FOOD_PELLET_TEXTURE: Texture2D = preload("res://assets/food/pellet_32.png")

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
@onready var feedback_container: Control = %FeedbackContainer
@onready var shop_panel: Control = %ShopPanel
@onready var coin_bubble_container: Control = %CoinBubbleContainer
@onready var runtime_log_panel: Control = %RuntimeLogPanel
@onready var log_toggle_button: Button = %LogToggleButton
@onready var modal_input_shield: ColorRect = %ModalInputShield
@onready var more_panel: PanelContainer = %MorePanel
@onready var more_items: GridContainer = %MoreItems
@onready var more_button: Button = %MoreButton
@onready var pet_roster: HBoxContainer = %PetRoster
@onready var pet_roster_backdrop: ColorRect = %PetRosterBackdrop
@onready var status_backdrop: ColorRect = %StatusBackdrop
@onready var status_scroll: ScrollContainer = %StatusScroll
@onready var top_panel: VBoxContainer = %TopPanel
@onready var inventory_backdrop: ColorRect = %InventoryBackdrop
@onready var action_backdrop: ColorRect = %ActionBackdrop
@onready var action_bar: GridContainer = %ActionBar
@onready var nursery_button: Button = %NurseryButton
@onready var pet_info_button: Button = %PetInfoButton
@onready var rename_button: Button = %RenameButton
@onready var rename_panel: PanelContainer = %RenamePanel
@onready var nickname_edit: LineEdit = %NicknameEdit
@onready var rename_confirm_button: Button = %RenameConfirmButton
@onready var rename_cancel_button: Button = %RenameCancelButton

var passive_timer: float = 0.0
var touch_cooldown: float = 0.0
var touch_status_timer: float = 0.0
var log_next_refresh: bool = false
var sick_generation_notice_shown: bool = false
var last_action_time_by_name: Dictionary = {}
var actors_by_id: Dictionary = {}
var coin_bubbles_by_id: Dictionary = {}
var food_drop_visuals: Dictionary = {}
var food_eating_visuals: Dictionary = {}
var food_sunk_at_msec: Dictionary = {}
var full_food_reactions_by_token: Dictionary = {}
var food_claims: Dictionary = {}
var roster_buttons_by_id: Dictionary = {}
var roster_buttons_by_slot: Array[Button] = []
var food_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var last_world_input_at: int = -1000
var last_world_input_position: Vector2 = Vector2.ZERO
var last_world_input_kind: int = -1
var world_input_pair_pending: bool = false
var rename_keyboard_request_count: int = 0
var active_water_rect: Rect2 = Rect2()
var rename_modal_active: bool = false
var pet_info_open: bool = false
var world_actions_enabled: bool = false

func _ready() -> void:
	DOS_STYLE.apply(self)
	RuntimeLogger.log_info("Aquarium entered")
	get_tree().quit_on_go_back = false
	get_window().go_back_requested.connect(_on_android_go_back_requested)
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
	more_button.pressed.connect(_on_more_pressed)
	pet_info_button.pressed.connect(_on_pet_info_toggle_pressed)
	log_toggle_button.visible = OS.is_debug_build()
	runtime_log_panel.visible = false
	status_backdrop.visible = true
	top_panel.visible = true
	_set_pet_info_widgets_visible(false)
	shop_panel.visibility_changed.connect(_sync_modal_input_shield)
	more_panel.visible = false
	rename_panel.visible = false
	nursery_button.pressed.connect(_on_nursery_pressed)
	rename_button.pressed.connect(_on_rename_pressed)
	rename_confirm_button.pressed.connect(_on_rename_confirmed)
	rename_cancel_button.pressed.connect(_close_rename_panel)
	nickname_edit.gui_input.connect(_on_nickname_gui_input)
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
	call_deferred("_enable_world_actions")


func _exit_tree() -> void:
	get_tree().quit_on_go_back = true


func _enable_world_actions() -> void:
	if is_inside_tree():
		world_actions_enabled = true


func _process(delta: float) -> void:
	_update_food_drops(delta)
	_apply_soft_actor_avoidance(delta)
	_update_selection_markers()
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
	var selected_pet_id: String = GameState.get_selected_pet_id()
	var drop_position: Vector2 = _next_food_spawn_position()
	_drop_basic_food(drop_position, selected_pet_id)


func _on_cookie_pressed() -> void:
	if not _accept_action("cookie"):
		return
	_close_more_menu()
	if GameState.get_inventory_count("cookie_basic") <= 0:
		_show_result(CareSystem.feed_cookie(GameState.get_selected_pet_id()), "餵了餅乾。", "餅乾不足。", false)
		return
	RuntimeLogger.log_action("Feed cookie clicked")
	_show_result(CareSystem.feed_cookie(GameState.get_selected_pet_id()), "餵了餅乾。", "餅乾不足。", false)


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
	_show_result(ok, "水母喵很開心。", "摸摸冷卻中。", false, false)


func _on_clean_pressed() -> void:
	if not _accept_action("clean"):
		return
	var aquarium: Dictionary = GameState.get_aquarium()
	var target_cleanliness: int = int(GameApp.get_balance_value("cleanliness_after_clean", 100))
	if int(aquarium.get("cleanliness", 0)) >= target_cleanliness:
		_close_more_menu()
		_show_result(CareSystem.clean_tank(), "魚缸已清潔。", "魚缸已經很乾淨。", true)
		return
	_close_more_menu()
	RuntimeLogger.log_action("Clean clicked")
	_show_result(CareSystem.clean_tank(), "魚缸已清潔。", "魚缸已經很乾淨。", true)


func _on_medicine_pressed() -> void:
	if not _accept_action("medicine"):
		return
	_close_more_menu()
	var pet_id: String = GameState.get_selected_pet_id()
	var pet: Dictionary = GameState.get_pet(pet_id)
	if pet.is_empty() or str(pet.get("health", "healthy")) == "healthy" or GameState.get_inventory_count("medicine_basic") <= 0:
		_show_result(CareSystem.give_medicine(pet_id), "已使用藥水。", "沒有藥水或尚未選擇寵物。", true)
		return
	RuntimeLogger.log_action("Medicine clicked")
	_show_result(CareSystem.give_medicine(pet_id), "已使用藥水。", "沒有藥水或尚未選擇寵物。", true)


func _on_evolve_pressed() -> void:
	if not _accept_action("evolve"):
		return
	_close_more_menu()
	var pet_id: String = GameState.get_selected_pet_id()
	var pet: Dictionary = GameState.get_pet(pet_id)
	var failure_message: String = "還不能進化。"
	var next_stage: Dictionary = EvolutionSystem.get_next_stage_data(pet_id)
	if next_stage.is_empty():
		failure_message = "已達最高階段或尚未選擇寵物。"
		_show_result(EvolutionSystem.evolve(pet_id), "水母喵進化了。", failure_message, true)
		return
	if pet.is_empty() or int(pet.get("growth_exp", 0)) < int(next_stage.get("required_growth_exp", 0)):
		_show_result(EvolutionSystem.evolve(pet_id), "水母喵進化了。", failure_message, true)
		return
	RuntimeLogger.log_action("Evolve clicked")
	var ok: bool = EvolutionSystem.evolve(pet_id)
	_show_result(ok, "水母喵進化了。", failure_message, true)


func _on_shop_pressed() -> void:
	if rename_modal_active or not _accept_action("shop"):
		return
	RuntimeLogger.log_action("Shop clicked")
	_close_more_menu()
	_set_shop_open(not shop_panel.visible)


func _set_shop_open(should_open: bool) -> void:
	if should_open:
		runtime_log_panel.visible = false
		more_panel.visible = false
	shop_panel.visible = should_open
	_sync_modal_input_shield()
	_apply_responsive_layout()
	if should_open:
		shop_panel.call("refresh")


func _sync_modal_input_shield() -> void:
	modal_input_shield.visible = shop_panel.visible or rename_modal_active


func _on_pet_info_toggle_pressed() -> void:
	if not world_actions_enabled or not _accept_action("pet_info"):
		return
	_set_pet_info_open(not pet_info_open)


func _set_pet_info_open(should_open: bool) -> void:
	if pet_info_open == should_open:
		_update_pet_info_button()
		return
	pet_info_open = should_open
	status_backdrop.visible = true
	top_panel.visible = true
	_set_pet_info_widgets_visible(should_open)
	_update_pet_info_button()
	_apply_responsive_layout()
	_refresh(false)


func _set_pet_info_widgets_visible(should_show: bool) -> void:
	coin_label.visible = true
	pet_info_button.visible = true
	rename_button.visible = should_show
	for detail_control in [
		stage_label,
		hunger_label,
		hunger_bar,
		mood_label,
		mood_bar,
		cleanliness_label,
		clean_bar,
		health_label,
		exp_label,
		touch_exp_label,
		evolution_label,
	]:
		detail_control.visible = should_show
	coin_label.add_theme_font_size_override("font_size", 22 if should_show else 16)


func _update_pet_info_button() -> void:
	pet_info_button.text = "收起資料" if pet_info_open else "寵物資料"
	pet_info_button.button_pressed = pet_info_open


func _on_daily_food_pressed() -> void:
	if not _accept_action("daily_food"):
		return
	_close_more_menu()
	_show_message("飼料已無限")


func _on_log_toggle_pressed() -> void:
	if rename_modal_active or not OS.is_debug_build() or not _accept_action("log_toggle"):
		return
	var should_show: bool = not runtime_log_panel.visible
	if should_show:
		_set_shop_open(false)
	_close_more_menu()
	runtime_log_panel.visible = should_show
	_apply_responsive_layout()
	_refresh(false)


func _on_more_pressed() -> void:
	if rename_modal_active or not _accept_action("more"):
		return
	var should_open: bool = not more_panel.visible
	if should_open:
		_set_shop_open(false)
		runtime_log_panel.visible = false
	more_panel.visible = should_open
	_apply_responsive_layout()
	_refresh(false)


func _close_more_menu() -> void:
	if not more_panel.visible:
		return
	more_panel.visible = false
	_apply_responsive_layout()


func _on_nursery_pressed() -> void:
	if not world_actions_enabled or not _accept_action("nursery"):
		return
	_close_more_menu()
	var eggs: Array[Dictionary] = GameState.get_nursery_eggs()
	if eggs.is_empty():
		_show_message("沒有蛋了")
		return
	if GameState.get_nursery_egg(GameState.get_active_egg_id()).is_empty():
		GameState.set_active_egg_id(str(eggs[0].get("egg_id", "")))
		SaveManager.save_game()
	SceneRouter.go_nursery()


func _select_next_unhatched_egg() -> bool:
	for egg in GameState.get_nursery_eggs():
		var egg_id: String = str(egg.get("egg_id", ""))
		if not egg_id.is_empty() and GameState.set_active_egg_id(egg_id):
			SaveManager.save_game()
			return true
	return false


func _on_rename_pressed() -> void:
	if not world_actions_enabled or shop_panel.visible or rename_modal_active:
		return
	var pet: Dictionary = GameState.get_pet(GameState.get_selected_pet_id())
	if pet.is_empty():
		return
	_close_more_menu()
	runtime_log_panel.visible = false
	_apply_responsive_layout()
	nickname_edit.text = str(pet.get("nickname", "JellyCat"))
	rename_modal_active = true
	rename_panel.visible = true
	_sync_modal_input_shield()
	_apply_responsive_layout()
	call_deferred("_request_rename_input_focus")


func _request_rename_input_focus() -> void:
	if not rename_modal_active or not is_instance_valid(nickname_edit):
		return
	NATIVE_TEXT_ENTRY.open_keyboard(nickname_edit, "aquarium_rename")
	rename_keyboard_request_count += 1


func _on_nickname_gui_input(event: InputEvent) -> void:
	NATIVE_TEXT_ENTRY.handle_gui_input(event, nickname_edit, "aquarium_rename")


func _close_rename_panel() -> void:
	var was_active: bool = rename_modal_active
	rename_modal_active = false
	rename_panel.hide()
	nickname_edit.release_focus()
	if was_active and OS.get_name() == "Android":
		DisplayServer.virtual_keyboard_hide()
	_sync_modal_input_shield()


func _on_rename_confirmed() -> void:
	if not rename_modal_active:
		return
	var pet_id: String = GameState.get_selected_pet_id()
	var pet: Dictionary = GameState.get_pet(pet_id)
	var nickname: String = nickname_edit.text.strip_edges().left(18)
	if pet.is_empty() or nickname.is_empty():
		_show_message("請輸入 1 至 18 個字元的名字。")
		return
	_close_rename_panel()
	if GameState.rename_pet(pet_id, nickname):
		SaveManager.save_game()
		_show_message("已改名為「%s」。" % nickname)
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
	_show_message("泡泡幣 +%d · %s" % [value, str(GameState.get_pet(source_pet_id).get("nickname", "水母喵"))])
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
	coin_label.text = "泡泡幣：%d" % GameState.get_currency("bubble_coin")
	stage_label.text = "%s　階段 %d · %s" % [str(jellycat.get("nickname", "水母喵")), int(jellycat.get("stage", 1)), str(stage_data.get("name", ""))]
	hunger_label.text = "飢餓：%d / 100" % hunger_value
	mood_label.text = "心情：%d / 100" % mood_value
	cleanliness_label.text = "清潔度：%d / 100" % cleanliness_value
	hunger_bar.value = hunger_value
	mood_bar.value = mood_value
	clean_bar.value = cleanliness_value
	var health_text: String = "生病" if str(jellycat.get("health", "healthy")) == "sick" else "正常"
	health_label.text = "健康：%s" % health_text
	exp_label.text = "成長經驗：%d" % growth_exp
	_refresh_touch_exp_label()
	inventory_label.text = "飼料 ∞\n餅乾 ×%d\n藥水 ×%d" % [
		GameState.get_inventory_count("cookie_basic"),
		GameState.get_inventory_count("medicine_basic")
	]
	if next_stage.is_empty():
		evolution_label.text = "下一階段：最高階"
	else:
		var exp_to_next: int = max(0, int(next_stage.get("required_growth_exp", 0)) - growth_exp)
		evolution_label.text = "下一階段：%s · 還需 %d 經驗" % [str(next_stage.get("name", "下一階段")), exp_to_next]
	_refresh_pet_roster()
	var egg_count: int = GameState.get_nursery_eggs().size()
	nursery_button.text = "育嬰室 %d" % egg_count if egg_count > 0 else "沒有蛋了"
	nursery_button.disabled = egg_count == 0
	nursery_button.tooltip_text = "剩餘蛋數：%d" % egg_count if egg_count > 0 else "沒有蛋了"
	for actor_id in actors_by_id.keys():
		var actor: Node = actors_by_id[actor_id] as Node
		if is_instance_valid(actor):
			actor.call("refresh_pet")
	log_toggle_button.text = "關閉日誌" if runtime_log_panel.visible else "開啟日誌"
	_update_selection_markers()
	if log_refresh:
		RuntimeLogger.log_info("Aquarium UI refreshed")


func _refresh_touch_exp_label() -> void:
	var care_stats: Dictionary = GameState.get_current_care_stats(GameState.get_selected_pet_id())
	var touch_cap: int = int(GameApp.get_balance_value("touch_growth_exp_cap", 20))
	var reset_seconds: float = max(float(GameApp.get_balance_value("touch_exp_reset_seconds", 600)), 1.0)
	var raw_start: String = str(care_stats.get("touch_exp_date", ""))
	var started_at: float = raw_start.to_float() if raw_start.is_valid_float() else 0.0
	var elapsed: float = Time.get_unix_time_from_system() - started_at
	if started_at <= 0.0 or elapsed < 0.0 or elapsed >= reset_seconds:
		touch_exp_label.text = "摸摸經驗：0/%d｜可累積" % touch_cap
		return
	var remaining: int = int(ceil(reset_seconds - elapsed))
	touch_exp_label.text = "摸摸經驗：%d/%d｜%02d:%02d 後重置" % [
		int(care_stats.get("touch_growth_exp_today", 0)),
		touch_cap,
		remaining / 60,
		remaining % 60
	]


func _accept_action(action_name: String) -> bool:
	if not world_actions_enabled:
		return false
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
		actor.connect("food_refused", Callable(self, "_on_actor_food_refused"))
		actor_anchor.add_child(actor)
		actor.call("set_water_bounds", local_water_bounds)
		actors_by_id[pet_id] = actor


func _refresh_pet_roster() -> void:
	_ensure_pet_roster_slots()
	var active_ids: Array[String] = GameState.get_active_pet_ids()
	roster_buttons_by_id.clear()
	var eggs_remaining: int = GameState.get_nursery_eggs().size()
	for slot_index in range(PET_SLOT_COUNT):
		var button: Button = roster_buttons_by_slot[slot_index]
		var label: Label = button.get_node("NameplateLabel") as Label
		if slot_index < active_ids.size():
			var pet_id: String = active_ids[slot_index]
			var pet: Dictionary = GameState.get_pet(pet_id)
			var nickname: String = str(pet.get("nickname", "")).strip_edges()
			if nickname.is_empty():
				nickname = "寵物 %d" % (slot_index + 1)
			var short_id: String = pet_id.trim_prefix("jc_")
			if short_id.is_valid_int():
				short_id = "%03d" % short_id.to_int()
			label.text = "%s · %s" % [nickname, short_id]
			button.tooltip_text = label.text
			button.disabled = false
			button.button_pressed = pet_id == GameState.get_selected_pet_id()
			roster_buttons_by_id[pet_id] = button
		else:
			label.text = "蛋　寵物 %d\n育嬰室" % (slot_index + 1) if eggs_remaining > 0 else "寵物 %d\n沒有蛋了" % (slot_index + 1)
			button.tooltip_text = "點此進入育嬰室" if eggs_remaining > 0 else "沒有蛋了"
			button.disabled = eggs_remaining == 0
			button.button_pressed = false
	_update_pet_info_button()


func _ensure_pet_roster_slots() -> void:
	while roster_buttons_by_slot.size() < PET_SLOT_COUNT:
		var slot_index: int = roster_buttons_by_slot.size()
		var button: Button = Button.new()
		button.name = "PetSlot%d" % (slot_index + 1)
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0.0, 64.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_pet_slot_pressed.bind(slot_index))
		var label: Label = Label.new()
		label.name = "NameplateLabel"
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.offset_left = 8.0
		label.offset_top = 4.0
		label.offset_right = -8.0
		label.offset_bottom = -4.0
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.clip_text = false
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 16)
		button.add_child(label)
		pet_roster.add_child(button)
		roster_buttons_by_slot.append(button)
		DOS_STYLE.style_button(button)


func _on_pet_slot_pressed(slot_index: int) -> void:
	if not world_actions_enabled or not _accept_action("pet_slot"):
		return
	var active_ids: Array[String] = GameState.get_active_pet_ids()
	if slot_index < active_ids.size():
		_on_pet_roster_pressed(active_ids[slot_index])
	else:
		_on_nursery_pressed()


func _on_pet_roster_pressed(pet_id: String) -> void:
	if not world_actions_enabled or not _accept_action("pet_select"):
		return
	if not GameState.get_active_pet_ids().has(pet_id):
		return
	GameState.set_selected_pet_id(pet_id)
	_set_pet_info_open(true)
	_refresh(false)


func _update_selection_markers() -> void:
	var selected_pet_id: String = GameState.get_selected_pet_id()
	for raw_pet_id in actors_by_id.keys():
		var pet_id: String = str(raw_pet_id)
		var actor: Node2D = actors_by_id.get(pet_id) as Node2D
		if not is_instance_valid(actor):
			continue
		var marker: Line2D = actor.get_node_or_null("SelectedPetIndicator") as Line2D
		if marker == null:
			marker = Line2D.new()
			marker.name = "SelectedPetIndicator"
			marker.z_index = -1
			marker.default_color = Color(1.0, 0.78, 0.08, 0.68)
			marker.width = 2.0
			marker.closed = true
			marker.antialiased = false
			actor.add_child(marker)
		var body_rect: Rect2 = actor.call("get_visual_body_rect_global")
		if body_rect.size == Vector2.ZERO:
			marker.visible = false
			continue
		actor.z_index = 1 if pet_id == selected_pet_id else 0
		var foot_position: Vector2 = Vector2(body_rect.get_center().x, body_rect.end.y + 6.0)
		marker.position = actor.to_local(foot_position)
		var radii: Vector2 = Vector2(body_rect.size.x * 0.3, maxf(1.5, body_rect.size.y * 0.01))
		marker.clear_points()
		for point_index in range(32):
			var angle: float = TAU * float(point_index) / 32.0
			marker.add_point(Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
		marker.visible = pet_id == selected_pet_id


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


func _layout_ui(viewport_size: Vector2, safe_rect: Rect2, touch_target_override: float = -1.0) -> void:
	var safe_left: float = maxf(0.0, safe_rect.position.x)
	var safe_top: float = maxf(0.0, safe_rect.position.y)
	var safe_right: float = minf(viewport_size.x, safe_rect.position.x + safe_rect.size.x)
	var safe_bottom: float = minf(viewport_size.y, safe_rect.position.y + safe_rect.size.y)
	var safe_width: float = maxf(1.0, safe_right - safe_left)
	var safe_height: float = maxf(1.0, safe_bottom - safe_top)
	var touch_target: float = touch_target_override if touch_target_override > 0.0 else DOS_STYLE.get_touch_target_height(viewport_size)
	var margin: float = clampf(touch_target * 0.15, 12.0, 24.0)
	var top_y: float = safe_top + margin
	for roster_button in roster_buttons_by_slot:
		roster_button.custom_minimum_size = Vector2(touch_target, touch_target)
	var roster_height: float = maxf(touch_target, pet_roster.get_combined_minimum_size().y)
	_place_control(pet_roster, Rect2(Vector2(safe_left + margin, top_y + 4.0), Vector2(maxf(1.0, safe_width - margin * 2.0), roster_height)))
	_place_control(pet_roster_backdrop, Rect2(pet_roster.position - Vector2(8.0, 4.0), pet_roster.size + Vector2(16.0, 8.0)))
	var status_top: float = pet_roster_backdrop.position.y + pet_roster_backdrop.size.y + 16.0
	var status_width: float = minf(maxf(1.0, safe_width - margin * 2.0), clampf(safe_width * (0.29 if pet_info_open else 0.16), 280.0 if pet_info_open else 156.0, 390.0 if pet_info_open else 220.0))
	var status_available_height: float = maxf(1.0, safe_bottom - margin - status_top)
	var status_content_height: float = maxf(touch_target + 32.0, top_panel.get_combined_minimum_size().y + 16.0)
	var status_height: float = minf(status_content_height, status_available_height)
	var status_rect: Rect2 = Rect2(Vector2(safe_left + margin, status_top), Vector2(status_width, status_height))
	_place_control(status_backdrop, status_rect)
	_place_control(status_scroll, Rect2(status_rect.position + Vector2(8.0, 8.0), status_rect.size - Vector2(16.0, 16.0)))
	top_panel.custom_minimum_size.x = maxf(1.0, status_scroll.size.x)
	for status_button in [pet_info_button, rename_button]:
		status_button.custom_minimum_size = Vector2(maxf(status_button.custom_minimum_size.x, touch_target), touch_target)
	var more_content: VBoxContainer = more_panel.get_node("MoreContent") as VBoxContainer
	var more_title: Label = more_panel.get_node("MoreContent/MoreTitle") as Label
	var more_items_scroll: ScrollContainer = more_panel.get_node("MoreContent/MoreItemsScroll") as ScrollContainer
	more_items.columns = maxi(1, more_items.get_child_count())
	more_content.add_theme_constant_override("separation", 4)
	more_title.add_theme_font_size_override("font_size", 16)
	var menu_button_min_height: float = maxf(touch_target, 112.0)
	for menu_node in more_items.get_children():
		if menu_node is Button:
			var menu_button: Button = menu_node as Button
			var menu_button_intrinsic_size: Vector2 = menu_button.get_minimum_size()
			var menu_button_width: float = maxf(maxf(touch_target, 112.0), menu_button_intrinsic_size.x)
			menu_button_min_height = maxf(menu_button_min_height, menu_button_intrinsic_size.y)
			menu_button.custom_minimum_size = Vector2(menu_button_width, menu_button_min_height)
	more_items_scroll.custom_minimum_size.y = menu_button_min_height
	for rename_action in [rename_confirm_button, rename_cancel_button]:
		rename_action.custom_minimum_size = Vector2(maxf(rename_action.custom_minimum_size.x, touch_target), touch_target)
	var right_width: float = minf(maxf(1.0, safe_width - margin * 2.0), clampf(safe_width * 0.13, 160.0, 280.0))
	var inventory_rect: Rect2 = Rect2(Vector2(safe_right - margin - right_width, top_y + roster_height + 12.0), Vector2(right_width, 126.0))
	_place_control(inventory_backdrop, inventory_rect)
	_place_control(inventory_label, Rect2(inventory_rect.position + Vector2(16.0, 12.0), inventory_rect.size - Vector2(32.0, 24.0)))
	var action_width_limit: float = maxf(1.0, safe_width - margin * 2.0)
	var action_columns: int = 2 if action_width_limit >= touch_target * 2.0 + 28.0 else 1
	var action_button_min_width: float = touch_target
	var action_button_min_height: float = touch_target
	if more_panel.visible and action_width_limit >= 4.0 * maxf(touch_target, 112.0) + 52.0:
		action_columns = 4
		action_button_min_width = maxf(touch_target, 112.0)
		action_button_min_height = maxf(touch_target, 112.0)
	action_bar.columns = action_columns
	var action_child_count: int = action_bar.get_child_count()
	var action_rows: int = ceili(float(action_child_count) / float(action_columns))
	var action_min_width: float = action_button_min_width * float(action_columns) + 12.0 * float(action_columns - 1) + 16.0
	var action_width: float = minf(action_width_limit, maxf(action_min_width, clampf(safe_width * 0.19, 216.0, 280.0)))
	var action_height_limit: float = maxf(1.0, safe_height - margin * 2.0)
	var action_content_height: float = float(action_rows) * action_button_min_height + float(action_rows - 1) * 12.0 + 16.0
	var action_height: float = minf(action_content_height, action_height_limit)
	var action_rect: Rect2 = Rect2(Vector2(safe_right - margin - action_width + 8.0, safe_bottom - margin - action_height + 8.0), Vector2(action_width - 16.0, action_height - 16.0))
	var button_width: float = maxf(1.0, (action_rect.size.x - float(action_columns - 1) * 12.0) / float(action_columns))
	for child in action_bar.get_children():
		if child is Button:
			(child as Button).custom_minimum_size = Vector2(button_width, action_button_min_height)
	_place_control(action_bar, action_rect)
	_place_control(action_backdrop, Rect2(action_bar.position - Vector2(8.0, 8.0), action_bar.size + Vector2(16.0, 16.0)))
	var log_width: float = minf(360.0, maxf(320.0, safe_width * 0.28))
	var log_height: float = minf(280.0, maxf(180.0, safe_height - margin * 2.0))
	runtime_log_panel.custom_minimum_size = Vector2(log_width, log_height)
	_place_control(runtime_log_panel, Rect2(Vector2(safe_left + margin, safe_bottom - margin - log_height), Vector2(log_width, log_height)))
	var shop_width: float = minf(360.0, maxf(320.0, safe_width * 0.34))
	var shop_height: float = maxf(220.0, shop_panel.get_combined_minimum_size().y)
	shop_panel.custom_minimum_size = Vector2(shop_width, shop_height)
	_place_control(shop_panel, Rect2(Vector2(safe_left + margin, minf(top_y + 416.0, safe_bottom - margin - shop_height)), Vector2(shop_width, shop_height)))
	var rename_width: float = minf(520.0, maxf(1.0, safe_width - margin * 2.0))
	nickname_edit.custom_minimum_size.x = maxf(120.0, rename_width - 32.0)
	var rename_height: float = minf(maxf(160.0, rename_panel.get_combined_minimum_size().y), maxf(1.0, safe_height - margin * 2.0))
	var rename_position: Vector2 = Vector2(safe_left + (safe_width - rename_width) * 0.5, safe_top + (safe_height - rename_height) * 0.5)
	_place_control(rename_panel, Rect2(rename_position, Vector2(rename_width, rename_height)))
	var message_left: float = status_rect.end.x + margin
	var message_right: float = minf(safe_right - margin - right_width - margin, action_backdrop.position.x - margin)
	var message_top: float = pet_roster_backdrop.position.y + pet_roster_backdrop.size.y + 16.0
	_place_control(message_label, Rect2(Vector2(message_left, message_top), Vector2(maxf(0.0, message_right - message_left), 38.0)))
	message_label.visible = not more_panel.visible
	if more_panel.visible:
		var menu_left: float = safe_left + margin
		var menu_available_width: float = maxf(1.0, safe_width - margin * 2.0)
		var menu_required_width: float = more_items.get_combined_minimum_size().x + 16.0
		var menu_width: float = minf(menu_available_width, maxf(280.0, menu_required_width))
		var menu_height: float = maxf(touch_target, more_panel.get_combined_minimum_size().y)
		var menu_x: float = menu_left + maxf(0.0, (menu_available_width - menu_width) * 0.5)
		var menu_y: float = action_bar.position.y - 8.0 - menu_height
		_place_control(more_panel, Rect2(Vector2(menu_x, menu_y), Vector2(menu_width, menu_height)))
	var left_panel_edge: float = safe_left
	for left_panel in [status_backdrop, runtime_log_panel, shop_panel, more_panel]:
		if left_panel.is_visible_in_tree():
			left_panel_edge = maxf(left_panel_edge, left_panel.position.x + left_panel.size.x)
	var right_panel_edge: float = safe_right
	for right_panel in [inventory_backdrop, action_backdrop, more_panel]:
		if right_panel.is_visible_in_tree():
			right_panel_edge = minf(right_panel_edge, right_panel.position.x)
	var top_panel_edge: float = safe_top
	for top_panel_control in [pet_roster_backdrop, message_label]:
		if top_panel_control.is_visible_in_tree():
			top_panel_edge = maxf(top_panel_edge, top_panel_control.position.y + top_panel_control.size.y)
	var water_left: float = maxf(safe_left + margin, left_panel_edge + margin)
	var water_right: float = minf(safe_right - margin, right_panel_edge - margin)
	var water_top: float = maxf(safe_top + margin, top_panel_edge + margin)
	var water_bottom: float = safe_bottom - margin
	active_water_rect = Rect2(Vector2(water_left, water_top), Vector2(maxf(1.0, water_right - water_left), maxf(1.0, water_bottom - water_top)))
	var previous_anchor_position: Vector2 = actor_anchor.position
	actor_anchor.position = active_water_rect.get_center()
	var anchor_delta: Vector2 = actor_anchor.position - previous_anchor_position
	var local_water_bounds: Rect2 = Rect2(-active_water_rect.size / 2.0, active_water_rect.size)
	var layout_actor_positions: Array[Vector2] = []
	for pet_id in GameState.get_active_pet_ids():
		var actor: Node2D = actors_by_id.get(pet_id) as Node2D
		if not is_instance_valid(actor):
			continue
		var target_position: Vector2 = actor.call(
			"set_layout_water_bounds",
			local_water_bounds,
			anchor_delta,
			LAYOUT_TRANSITION_SECONDS,
			layout_actor_positions,
			touch_target
		)
		layout_actor_positions.append(target_position)


func _place_control(control: Control, target_rect: Rect2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = target_rect.position
	control.size = target_rect.size


func _actor_spawn_position(index: int, count: int) -> Vector2:
	if count <= 1:
		return Vector2.ZERO
	var spacing: float = active_water_rect.size.x * 0.64 / float(count - 1)
	return Vector2((float(index) - float(count - 1) / 2.0) * spacing, 0.0)


func _apply_soft_actor_avoidance(delta: float) -> void:
	if delta <= 0.0:
		return
	var pet_ids: Array[String] = GameState.get_active_pet_ids()
	var separation_speed: float = maxf(120.0, float(GameApp.get_balance_value("actor_swim_speed", 32.0)) * 4.0)
	for first_index in range(pet_ids.size()):
		var first_id: String = pet_ids[first_index]
		var first_actor: Node2D = actors_by_id.get(first_id) as Node2D
		if not is_instance_valid(first_actor) or str(first_actor.get("behavior_state")) != "idle_roam":
			continue
		for second_index in range(first_index + 1, pet_ids.size()):
			var second_id: String = pet_ids[second_index]
			var second_actor: Node2D = actors_by_id.get(second_id) as Node2D
			if not is_instance_valid(second_actor) or str(second_actor.get("behavior_state")) != "idle_roam":
				continue
			var first_rect: Rect2 = first_actor.call("get_visual_body_rect_global")
			var second_rect: Rect2 = second_actor.call("get_visual_body_rect_global")
			var first_area: float = first_rect.size.x * first_rect.size.y
			var second_area: float = second_rect.size.x * second_rect.size.y
			var minimum_area: float = minf(first_area, second_area)
			if minimum_area <= 0.0:
				continue
			var overlap: Rect2 = first_rect.intersection(second_rect)
			var overlap_area: float = overlap.size.x * overlap.size.y
			if overlap_area / minimum_area <= 0.5:
				continue
			var centers_delta: Vector2 = second_rect.get_center() - first_rect.get_center()
			var separation_axis: Vector2
			var overlap_on_axis: float
			if absf(centers_delta.x) >= absf(centers_delta.y):
				var horizontal_sign: float = signf(centers_delta.x)
				if is_zero_approx(horizontal_sign):
					horizontal_sign = 1.0 if first_id < second_id else -1.0
				separation_axis = Vector2(horizontal_sign, 0.0)
				overlap_on_axis = overlap.size.x
			else:
				var vertical_sign: float = signf(centers_delta.y)
				if is_zero_approx(vertical_sign):
					vertical_sign = 1.0 if first_id < second_id else -1.0
				separation_axis = Vector2(0.0, vertical_sign)
				overlap_on_axis = overlap.size.y
			var correction: float = minf(overlap_on_axis * 0.6, separation_speed * delta)
			var half_correction: Vector2 = separation_axis * correction * 0.5
			first_actor.position = first_actor.call("_clamp_to_water", first_actor.position - half_correction)
			second_actor.position = second_actor.call("_clamp_to_water", second_actor.position + half_correction)
			first_actor.set("roam_target", first_actor.call("_clamp_to_water", first_actor.get("roam_target") - half_correction))
			second_actor.set("roam_target", second_actor.call("_clamp_to_water", second_actor.get("roam_target") + half_correction))


func _has_sick_active_pet() -> bool:
	for pet_id in GameState.get_active_pet_ids():
		if str(GameState.get_pet(pet_id).get("health", "healthy")) == "sick":
			return true
	return false


func _drop_basic_food(screen_position: Vector2, target_pet_id: String = "") -> Dictionary:
	screen_position = _clamp_food_interaction_point(screen_position)
	_expire_due_food_drops()
	if GameState.get_food_drops().size() >= GameState.MAX_ACTIVE_FOOD_DROPS:
		_show_message("飼料已達上限（%d）。" % GameState.MAX_ACTIVE_FOOD_DROPS)
		return {}
	var drop: Dictionary = FoodDropSystem.drop_food(screen_position)
	if drop.is_empty():
		_show_message("無法投放飼料。")
		return {}
	var token_id: String = str(drop.get("token_id", ""))
	if not token_id.is_empty() and GameState.get_active_pet_ids().has(target_pet_id) and not food_claims.values().has(target_pet_id):
		food_claims[token_id] = target_pet_id
	RuntimeLogger.log_action("Basic food dropped: %s" % str(drop.get("token_id", "")))
	_show_message("飼料正在下沉。")
	return drop


func _next_food_spawn_position() -> Vector2:
	var columns: int = clampi(int(floor(active_water_rect.size.x / 96.0)), 1, 5)
	var rows: int = ceili(float(GameState.MAX_ACTIVE_FOOD_DROPS) / float(columns))
	var slot_count: int = maxi(1, columns * rows)
	var starting_index: int = GameState.get_food_drops().size() % slot_count
	var best_position: Vector2 = active_water_rect.get_center()
	var best_clearance: float = -1.0
	for offset in range(slot_count):
		var slot_index: int = (starting_index + offset) % slot_count
		var column: int = slot_index % columns
		var row: int = slot_index / columns
		var x_ratio: float = (float(column) + 0.5) / float(columns)
		var y_ratio: float = 0.5 if rows == 1 else 0.25 + 0.5 * float(row) / float(rows - 1)
		var candidate: Vector2 = Vector2(
			active_water_rect.position.x + active_water_rect.size.x * x_ratio,
			active_water_rect.position.y + active_water_rect.size.y * y_ratio
		)
		candidate = _clamp_food_interaction_point(candidate)
		var nearest_clearance: float = INF
		var overlaps_actor: bool = false
		for pet_id in actors_by_id.keys():
			var actor: Node2D = actors_by_id.get(str(pet_id)) as Node2D
			if not is_instance_valid(actor):
				continue
			var body_rect: Rect2 = actor.call("get_visual_body_rect_global")
			var marker_rect: Rect2 = Rect2(candidate - FOOD_DISPLAY_SIZE * 0.5, FOOD_DISPLAY_SIZE)
			var separation: float = marker_rect.get_center().distance_to(body_rect.get_center()) - body_rect.size.length() * 0.5
			nearest_clearance = minf(nearest_clearance, separation)
			if marker_rect.intersects(body_rect.grow(12.0)):
				overlaps_actor = true
		if not overlaps_actor:
			return candidate
		if nearest_clearance > best_clearance:
			best_clearance = nearest_clearance
			best_position = candidate
	return best_position


func _update_food_drops(delta: float) -> void:
	_expire_due_food_drops()
	var drops: Array[Dictionary] = GameState.get_food_drops()
	var drops_by_token: Dictionary = {}
	var sunk_tokens_to_remove: Array[String] = []
	var now_msec: int = Time.get_ticks_msec()
	for drop in drops:
		var token_id: String = str(drop.get("token_id", ""))
		if token_id.is_empty():
			continue
		drops_by_token[token_id] = drop
		if not food_drop_visuals.has(token_id):
			var food: TextureRect = _create_food_marker()
			food_drop_container.add_child(food)
			var initial_center: Vector2 = _clamp_food_interaction_point(
				Vector2(float(drop.get("x", 0.0)), float(drop.get("y", 0.0)))
			)
			food.global_position = initial_center - FOOD_DISPLAY_SIZE / 2.0
			food_drop_visuals[token_id] = food
		var visual: Control = food_drop_visuals[token_id] as Control
		if visual == null:
			continue
		if food_eating_visuals.has(token_id):
			_update_food_eating_visual(token_id, visual, delta)
			continue
		var interaction_point: Vector2 = _clamp_food_interaction_point(_food_marker_center(visual))
		var floor_y: float = active_water_rect.end.y - FOOD_DISPLAY_SIZE.y / 2.0
		interaction_point.y = minf(
			floor_y,
			interaction_point.y + float(GameApp.get_balance_value("food_sink_speed", 18.0)) * delta
		)
		visual.global_position = interaction_point - visual.size / 2.0
		if interaction_point.y >= floor_y - 0.5:
			if not food_sunk_at_msec.has(token_id):
				food_sunk_at_msec[token_id] = now_msec
			elif now_msec - int(food_sunk_at_msec[token_id]) >= FOOD_SUNK_CLEANUP_MSEC:
				sunk_tokens_to_remove.append(token_id)
		else:
			food_sunk_at_msec.erase(token_id)

	for token_id in food_drop_visuals.keys():
		if drops_by_token.has(str(token_id)):
			continue
		var stale_visual: Node = food_drop_visuals[token_id] as Node
		food_drop_visuals.erase(token_id)
		food_eating_visuals.erase(token_id)
		food_sunk_at_msec.erase(token_id)
		if is_instance_valid(stale_visual):
			stale_visual.queue_free()

	for token_id in full_food_reactions_by_token.keys():
		if drops_by_token.has(str(token_id)):
			continue
		var stale_reactions: Dictionary = full_food_reactions_by_token[token_id] as Dictionary
		for raw_pet_id in stale_reactions.keys():
			var stale_actor: Node = actors_by_id.get(str(raw_pet_id)) as Node
			if stale_actor != null:
				stale_actor.call("clear_full_food_target", str(token_id))
		full_food_reactions_by_token.erase(token_id)

	for token_id in food_claims.keys():
		if not drops_by_token.has(str(token_id)):
			var former_pet_id: String = str(food_claims[token_id])
			var former_actor: Node = actors_by_id.get(former_pet_id) as Node
			if former_actor != null:
				former_actor.call("clear_food_target", str(token_id))
			food_claims.erase(token_id)
			continue
		var claimed_pet_id: String = str(food_claims[token_id])
		if int(GameState.get_pet(claimed_pet_id).get("hunger", 100)) >= 95:
			var full_actor: Node = actors_by_id.get(claimed_pet_id) as Node
			if full_actor != null:
				full_actor.call("clear_food_target", str(token_id))
			food_claims.erase(token_id)

	var occupied_pet_ids: Dictionary = {}
	for token_id in food_claims.keys():
		occupied_pet_ids[str(food_claims[token_id])] = true
	for drop in drops:
		var token_id: String = str(drop.get("token_id", ""))
		if food_claims.has(token_id):
			continue
		var visual: Control = food_drop_visuals.get(token_id) as Control
		if visual == null:
			continue
		var pet_id: String = _choose_food_pet(occupied_pet_ids, _food_marker_center(visual))
		if pet_id.is_empty():
			continue
		food_claims[token_id] = pet_id
		occupied_pet_ids[pet_id] = true

	for token_id in food_claims.keys():
		var pet_id: String = str(food_claims[token_id])
		var actor: Node2D = actors_by_id.get(pet_id) as Node2D
		var visual: Control = food_drop_visuals.get(token_id) as Control
		if actor == null or visual == null or not actor.call("can_accept_food"):
			continue
		var interaction_point: Vector2 = _food_marker_center(visual)
		var target_position: Vector2 = actor_anchor.to_local(interaction_point)
		actor.call("set_food_target", str(token_id), target_position)
		if _actor_contacts_food(actor, visual):
			actor.call("begin_eating", str(token_id))
			_begin_food_eating_visual(str(token_id), actor, visual)

	var reacting_pet_ids: Dictionary = {}
	for drop in drops:
		var token_id: String = str(drop.get("token_id", ""))
		var visual: Control = food_drop_visuals.get(token_id) as Control
		if token_id.is_empty() or visual == null:
			continue
		var reactions: Dictionary = full_food_reactions_by_token.get(token_id, {}) as Dictionary
		var target_position: Vector2 = actor_anchor.to_local(_food_marker_center(visual))
		for pet_id in GameState.get_active_pet_ids():
			if reacting_pet_ids.has(pet_id) or occupied_pet_ids.has(pet_id):
				continue
			if reactions.has(pet_id):
				var existing_actor: Node2D = actors_by_id.get(pet_id) as Node2D
				if existing_actor != null and str(existing_actor.get("full_food_drop_id")) == token_id:
					var existing_state: String = str(existing_actor.get("behavior_state"))
					if existing_state == "approach_full_food":
						existing_actor.call("set_full_food_target", token_id, target_position)
						reacting_pet_ids[pet_id] = true
					elif existing_state == "full_food_refusal":
						reacting_pet_ids[pet_id] = true
				continue
			if int(GameState.get_pet(pet_id).get("hunger", 100)) < 95:
				continue
			var actor: Node2D = actors_by_id.get(pet_id) as Node2D
			if actor == null or not bool(actor.call("can_react_to_full_food")):
				continue
			if actor.call("set_full_food_target", token_id, target_position):
				reactions[pet_id] = true
				reacting_pet_ids[pet_id] = true
		full_food_reactions_by_token[token_id] = reactions

	for token_id in sunk_tokens_to_remove:
		if GameState.resolve_food_drop(token_id):
			SaveManager.save_game()
			RuntimeLogger.log_info("food expired/cleared %s" % token_id)
			_remove_food_token_visual(token_id)


func _expire_due_food_drops() -> void:
	var now: float = Time.get_unix_time_from_system()
	var expired_tokens: Array[String] = []
	for drop in GameState.get_food_drops():
		var token_id: String = str(drop.get("token_id", ""))
		if not token_id.is_empty() and float(drop.get("expires_at", 0.0)) <= now:
			expired_tokens.append(token_id)
	if expired_tokens.is_empty():
		return
	FoodDropSystem.expire_due_drops()
	var remaining_tokens: Dictionary = {}
	for drop in GameState.get_food_drops():
		remaining_tokens[str(drop.get("token_id", ""))] = true
	for token_id in expired_tokens:
		if not remaining_tokens.has(token_id):
			RuntimeLogger.log_info("food expired/cleared %s" % token_id)


func _choose_food_pet(occupied_pet_ids: Dictionary, food_position: Vector2) -> String:
	var lowest_hunger: int = 101
	var closest_distance: float = INF
	var closest_pet_id: String = ""
	for pet_id in GameState.get_active_pet_ids():
		if occupied_pet_ids.has(pet_id):
			continue
		var actor: Node2D = actors_by_id.get(pet_id) as Node2D
		var pet: Dictionary = GameState.get_pet(pet_id)
		var hunger: int = int(pet.get("hunger", 100))
		if actor == null or not bool(actor.call("can_accept_food")) or hunger >= 95:
			continue
		var distance: float = actor.global_position.distance_to(food_position)
		if hunger < lowest_hunger or (hunger == lowest_hunger and distance < closest_distance):
			lowest_hunger = hunger
			closest_distance = distance
			closest_pet_id = pet_id
	return closest_pet_id


func _create_food_marker() -> TextureRect:
	var marker: TextureRect = TextureRect.new()
	marker.name = "FoodMarker"
	marker.size = FOOD_DISPLAY_SIZE
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.focus_mode = Control.FOCUS_NONE
	marker.texture = FOOD_PELLET_TEXTURE
	marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return marker


func _food_marker_center(marker: Control) -> Vector2:
	return marker.global_position + marker.size / 2.0


func _food_marker_rect(marker: Control) -> Rect2:
	var marker_center: Vector2 = _food_marker_center(marker)
	return Rect2(marker_center - FOOD_INTERACTION_SIZE / 2.0, FOOD_INTERACTION_SIZE)


func _clamp_food_interaction_point(value: Vector2) -> Vector2:
	return _clamp_to_rect(value, active_water_rect, FOOD_DISPLAY_SIZE.x / 2.0)


func _actor_contacts_food(actor: Node2D, marker: Control) -> bool:
	var body_rect: Rect2 = actor.call("get_visual_body_rect_global")
	return body_rect.intersects(_food_marker_rect(marker))


func _on_actor_food_eaten(token_id: String, pet_id: String) -> void:
	var actor: Node = actors_by_id.get(pet_id) as Node
	var old_hunger: int = int(GameState.get_pet(pet_id).get("hunger", 0))
	var success: bool = FoodDropSystem.consume_food(token_id, pet_id)
	food_claims.erase(token_id)
	var visual: Node = food_drop_visuals.get(token_id) as Node
	food_drop_visuals.erase(token_id)
	food_eating_visuals.erase(token_id)
	food_sunk_at_msec.erase(token_id)
	if is_instance_valid(visual):
		visual.queue_free()
	var reactions: Dictionary = full_food_reactions_by_token.get(token_id, {}) as Dictionary
	for raw_pet_id in reactions.keys():
		var reacting_actor: Node = actors_by_id.get(str(raw_pet_id)) as Node
		if reacting_actor != null:
			reacting_actor.call("clear_full_food_target", token_id)
	full_food_reactions_by_token.erase(token_id)
	if actor == null:
		return
	if success:
		actor.call("complete_meal", token_id)
		var new_hunger: int = int(GameState.get_pet(pet_id).get("hunger", old_hunger))
		var satiation_gained: int = maxi(0, new_hunger - old_hunger)
		RuntimeLogger.log_info("food eaten %s by %s" % [token_id, pet_id])
		RuntimeLogger.log_state("hunger %d -> %d" % [old_hunger, new_hunger])
		_show_message("%s 吃了飼料，飽足度 +%d。" % [str(GameState.get_pet(pet_id).get("nickname", "水母喵")), satiation_gained])
	else:
		actor.call("clear_food_target", token_id)


func _begin_food_eating_visual(token_id: String, actor: Node2D, visual: Control) -> void:
	if food_eating_visuals.has(token_id):
		return
	food_eating_visuals[token_id] = {
		"elapsed": 0.0,
		"start_center": _food_marker_center(visual),
		"pet_id": str(actor.get("pet_id")),
	}


func _update_food_eating_visual(token_id: String, visual: Control, delta: float) -> void:
	var animation: Dictionary = food_eating_visuals.get(token_id, {}) as Dictionary
	var actor: Node2D = actors_by_id.get(str(animation.get("pet_id", ""))) as Node2D
	if actor == null or animation.is_empty():
		food_eating_visuals.erase(token_id)
		visual.size = FOOD_DISPLAY_SIZE
		visual.visible = true
		return
	var elapsed: float = minf(FOOD_EAT_ANIMATION_SECONDS, float(animation.get("elapsed", 0.0)) + maxf(delta, 0.0))
	animation["elapsed"] = elapsed
	food_eating_visuals[token_id] = animation
	var progress: float = clampf(elapsed / FOOD_EAT_ANIMATION_SECONDS, 0.0, 1.0)
	var eased_progress: float = progress * progress * (3.0 - 2.0 * progress)
	var start_center: Vector2 = animation.get("start_center", _food_marker_center(visual)) as Vector2
	var mouth_offset: float = maxf(float(actor.call("get_visual_body_size").y) * 0.15, 10.0)
	var mouth_position: Vector2 = actor.global_position - Vector2(0.0, mouth_offset)
	var center: Vector2 = start_center.lerp(mouth_position, eased_progress)
	visual.size = FOOD_DISPLAY_SIZE * (1.0 - eased_progress)
	visual.global_position = center - visual.size / 2.0
	if progress >= 1.0:
		visual.visible = false


func _on_actor_food_refused(token_id: String, pet_id: String) -> void:
	if not full_food_reactions_by_token.get(token_id, {}).has(pet_id):
		return
	if int(GameState.get_pet(pet_id).get("hunger", 100)) < 95:
		return
	var actor: Node2D = actors_by_id.get(pet_id) as Node2D
	if actor == null:
		return
	RuntimeLogger.log_info("full refusal %s" % pet_id)
	var bubble: Label = Label.new()
	bubble.name = "FullFoodRefusalBubble"
	bubble.text = "吃飽了"
	bubble.custom_minimum_size = Vector2(128.0, 60.0)
	bubble.size = Vector2(128.0, 60.0)
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_theme_font_size_override("font_size", 20)
	bubble.add_theme_color_override("font_color", Color("fff6b0"))
	bubble.add_theme_color_override("font_outline_color", Color("1c1838"))
	bubble.add_theme_constant_override("outline_size", 3)
	feedback_container.add_child(bubble)
	var body_rect: Rect2 = actor.call("get_visual_body_rect_global")
	var viewport_rect: Rect2 = get_viewport_rect()
	var bubble_y: float = body_rect.position.y - bubble.size.y - 40.0
	if bubble_y < viewport_rect.position.y:
		bubble_y = minf(body_rect.end.y + 8.0, viewport_rect.end.y - bubble.size.y)
	var bubble_x: float = body_rect.get_center().x - bubble.size.x * 0.5
	var horizontal_step: float = bubble.size.x + 8.0
	var horizontal_offsets: Array[float] = [0.0, -horizontal_step, horizontal_step, -horizontal_step * 2.0, horizontal_step * 2.0]
	for horizontal_offset in horizontal_offsets:
		var candidate_x: float = clampf(bubble_x + horizontal_offset, viewport_rect.position.x, viewport_rect.end.x - bubble.size.x)
		var candidate_rect: Rect2 = Rect2(Vector2(candidate_x, bubble_y), bubble.size)
		var overlaps_feedback: bool = false
		for existing_feedback in feedback_container.get_children():
			if existing_feedback == bubble or not (existing_feedback is Label) or str((existing_feedback as Label).text) != "吃飽了":
				continue
			if candidate_rect.intersects((existing_feedback as Label).get_global_rect()):
				overlaps_feedback = true
				break
		if not overlaps_feedback:
			bubble_x = candidate_x
			break
	bubble.global_position = Vector2(
		bubble_x,
		clampf(bubble_y, viewport_rect.position.y, viewport_rect.end.y - bubble.size.y)
	)
	var tween: Tween = bubble.create_tween()
	tween.set_parallel(true)
	tween.tween_property(bubble, "global_position:y", bubble.global_position.y - 18.0, 1.1)
	tween.tween_property(bubble, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.tween_callback(bubble.queue_free).set_delay(1.1)


func _remove_food_token_visual(token_id: String) -> void:
	var claimed_pet_id: String = str(food_claims.get(token_id, ""))
	var claimed_actor: Node = actors_by_id.get(claimed_pet_id) as Node
	if claimed_actor != null:
		claimed_actor.call("clear_food_target", token_id)
	food_claims.erase(token_id)
	var reactions: Dictionary = full_food_reactions_by_token.get(token_id, {}) as Dictionary
	for raw_pet_id in reactions.keys():
		var reacting_actor: Node = actors_by_id.get(str(raw_pet_id)) as Node
		if reacting_actor != null:
			reacting_actor.call("clear_full_food_target", token_id)
	full_food_reactions_by_token.erase(token_id)
	food_eating_visuals.erase(token_id)
	food_sunk_at_msec.erase(token_id)
	var visual: Node = food_drop_visuals.get(token_id) as Node
	food_drop_visuals.erase(token_id)
	if is_instance_valid(visual):
		visual.queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if not world_actions_enabled or modal_input_shield.visible:
		return
	var screen_position: Vector2
	var input_kind: int
	if event is InputEventScreenTouch:
		if not (event as InputEventScreenTouch).pressed:
			return
		screen_position = (event as InputEventScreenTouch).position
		input_kind = 0
	elif event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		screen_position = mouse_event.position
		input_kind = 1
	else:
		return
	if not _get_safe_viewport_rect(get_viewport_rect().size).has_point(screen_position) or not active_water_rect.has_point(screen_position):
		return
	var now: int = Time.get_ticks_msec()
	if world_input_pair_pending and input_kind != last_world_input_kind and now - last_world_input_at < WORLD_INPUT_PAIR_DEBOUNCE_MSEC and screen_position.distance_to(last_world_input_position) < 2.0:
		world_input_pair_pending = false
		return
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
		_set_pet_info_open(true)
		selected_actor.call("react_to_touch")
		_record_world_input(screen_position, input_kind)
		return
	_drop_basic_food(screen_position)
	_record_world_input(screen_position, input_kind)


func _record_world_input(screen_position: Vector2, input_kind: int) -> void:
	last_world_input_at = Time.get_ticks_msec()
	last_world_input_position = screen_position
	last_world_input_kind = input_kind
	world_input_pair_pending = true


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != KEY_ESCAPE and not key_event.is_action_pressed("ui_cancel"):
		return
	if not _close_topmost_panel():
		return
	get_viewport().set_input_as_handled()


func _on_android_go_back_requested() -> void:
	if not _close_topmost_panel():
		get_tree().quit()


func _close_topmost_panel() -> bool:
	if rename_modal_active:
		_close_rename_panel()
	elif shop_panel.visible:
		_set_shop_open(false)
	elif more_panel.visible:
		_close_more_menu()
	elif runtime_log_panel.visible:
		runtime_log_panel.visible = false
		_apply_responsive_layout()
		_refresh(false)
	else:
		return false
	return true


func _clamp_to_rect(value: Vector2, rect: Rect2, margin: float) -> Vector2:
	var horizontal_margin: float = minf(margin, rect.size.x * 0.5)
	var vertical_margin: float = minf(margin, rect.size.y * 0.5)
	return Vector2(
		clampf(value.x, rect.position.x + horizontal_margin, rect.end.x - horizontal_margin),
		clampf(value.y, rect.position.y + vertical_margin, rect.end.y - vertical_margin)
	)
