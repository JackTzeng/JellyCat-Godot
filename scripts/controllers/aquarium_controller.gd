extends Control

const COIN_BUBBLE_SCENE: PackedScene = preload("res://scenes/ui/coin_bubble_pickup.tscn")
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
@onready var jellycat_actor: Node2D = %JellyCatActor
@onready var shop_panel: Control = %ShopPanel
@onready var coin_bubble_container: Control = %CoinBubbleContainer
@onready var runtime_log_panel: Control = %RuntimeLogPanel

var passive_timer: float = 0.0
var touch_cooldown: float = 0.0
var touch_status_timer: float = 0.0
var log_next_refresh: bool = false
var sick_generation_notice_shown: bool = false
var last_action_time_by_name: Dictionary = {}

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
	_refresh(true)
	var jellycat: Variant = GameState.get_jellycat()
	if jellycat is Dictionary and str(jellycat.get("health", "healthy")) == "sick":
		RuntimeLogger.log_info("JellyCat is sick, bubble coin generation paused")
		sick_generation_notice_shown = true


func _process(delta: float) -> void:
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
	if GameState.get_inventory_count("food_basic") <= 0:
		_show_result(CareSystem.feed_food(), "Fed basic food.", "Not enough food.", false)
		return
	RuntimeLogger.log_action("Feed food clicked")
	_show_result(CareSystem.feed_food(), "Fed basic food.", "Not enough food.", false)


func _on_cookie_pressed() -> void:
	if not _accept_action("cookie"):
		return
	if GameState.get_inventory_count("cookie_basic") <= 0:
		_show_result(CareSystem.feed_cookie(), "Fed cookie.", "Not enough cookie.", false)
		return
	RuntimeLogger.log_action("Feed cookie clicked")
	_show_result(CareSystem.feed_cookie(), "Fed cookie.", "Not enough cookie.", false)


func _on_touch_pressed() -> void:
	if not _accept_action("touch"):
		return
	if touch_cooldown > 0.0:
		return
	var ok: bool = CareSystem.touch_pet()
	if ok:
		touch_cooldown = float(GameApp.get_balance_value("touch_cooldown_seconds", DEFAULT_TOUCH_COOLDOWN_SECONDS))
	_show_result(ok, "JellyCat feels happy.", "Touch cooling down.", false, false)


func _on_clean_pressed() -> void:
	if not _accept_action("clean"):
		return
	var jellycat: Variant = GameState.get_jellycat()
	if jellycat is Dictionary:
		var target_cleanliness: int = int(GameApp.get_balance_value("cleanliness_after_clean", 100))
		if int(jellycat.get("cleanliness", 0)) >= target_cleanliness:
			_show_result(CareSystem.clean_tank(), "Tank cleaned.", "Tank is already clean.", true)
			return
	RuntimeLogger.log_action("Clean clicked")
	_show_result(CareSystem.clean_tank(), "Tank cleaned.", "No jellycat found.", true)


func _on_medicine_pressed() -> void:
	if not _accept_action("medicine"):
		return
	var jellycat: Variant = GameState.get_jellycat()
	if jellycat is Dictionary:
		if str(jellycat.get("health", "healthy")) == "healthy" or GameState.get_inventory_count("medicine_basic") <= 0:
			_show_result(CareSystem.give_medicine(), "Medicine used.", "No medicine or no jellycat.", true)
			return
	RuntimeLogger.log_action("Medicine clicked")
	_show_result(CareSystem.give_medicine(), "Medicine used.", "No medicine or no jellycat.", true)


func _on_evolve_pressed() -> void:
	if not _accept_action("evolve"):
		return
	var failure_message: String = "Cannot evolve yet."
	var next_stage: Dictionary = EvolutionSystem.get_next_stage_data()
	var jellycat: Variant = GameState.get_jellycat()
	if next_stage.is_empty():
		failure_message = "Already max stage."
		_show_result(EvolutionSystem.evolve(), "JellyCat evolved.", failure_message, true)
		return
	if not (jellycat is Dictionary) or int(jellycat.get("growth_exp", 0)) < int(next_stage.get("required_growth_exp", 0)):
		_show_result(EvolutionSystem.evolve(), "JellyCat evolved.", failure_message, true)
		return
	RuntimeLogger.log_action("Evolve clicked")
	var ok: bool = EvolutionSystem.evolve()
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
	var jellycat: Variant = GameState.get_jellycat()
	if jellycat is Dictionary and str(jellycat.get("health", "healthy")) == "sick":
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
	_refresh(false)


func _refresh(log_refresh: bool = false) -> void:
	var jellycat: Variant = GameState.get_jellycat()
	if not (jellycat is Dictionary):
		RuntimeLogger.log_error("No jellycat found")
		return
	var stage_data: Dictionary = EvolutionSystem.get_current_stage_data()
	var next_stage: Dictionary = EvolutionSystem.get_next_stage_data()
	var hunger_value: int = int(jellycat.get("hunger", 0))
	var mood_value: int = int(jellycat.get("mood", 0))
	var cleanliness_value: int = int(jellycat.get("cleanliness", 0))
	var growth_exp: int = int(jellycat.get("growth_exp", 0))
	coin_label.text = "Bubble Coin: %d" % GameState.get_currency("bubble_coin")
	stage_label.text = "%s  Stage %d" % [stage_data.get("name", "JellyCat"), int(jellycat.get("stage", 1))]
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
	actor_anchor.scale = Vector2.ONE
	jellycat_actor.call("set_stage", int(jellycat.get("stage", 1)))
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
	var care_stats: Dictionary = GameState.get_care_stats()
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
