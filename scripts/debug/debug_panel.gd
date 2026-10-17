extends PanelContainer

@onready var info_label: Label = %InfoLabel

func _ready() -> void:
	%HungerButton.pressed.connect(_on_hunger_pressed)
	%MoodButton.pressed.connect(_on_mood_pressed)
	%ExpButton.pressed.connect(_on_exp_pressed)
	%CoinButton.pressed.connect(_on_coin_pressed)
	%EvolveButton.pressed.connect(_on_evolve_pressed)
	%DayButton.pressed.connect(_on_day_pressed)
	%WeekButton.pressed.connect(_on_week_pressed)
	%ResetButton.pressed.connect(_on_reset_pressed)
	refresh()

func _on_hunger_pressed() -> void:
	DebugTools.add_hunger(GameState.get_selected_pet_id())
	refresh()

func _on_mood_pressed() -> void:
	DebugTools.add_mood(GameState.get_selected_pet_id())
	refresh()

func _on_exp_pressed() -> void:
	DebugTools.add_growth_exp(GameState.get_selected_pet_id())
	refresh()

func _on_coin_pressed() -> void:
	DebugTools.add_bubble_coin()
	refresh()

func _on_evolve_pressed() -> void:
	DebugTools.direct_evolve(GameState.get_selected_pet_id())
	refresh()

func _on_day_pressed() -> void:
	DebugTools.simulate_days(1)
	refresh()

func _on_week_pressed() -> void:
	DebugTools.simulate_days(7)
	refresh()

func _on_reset_pressed() -> void:
	DebugTools.reset_save()

func refresh() -> void:
	var pet_id: String = GameState.get_selected_pet_id()
	var pet: Dictionary = GameState.get_pet(pet_id)
	var egg: Dictionary = GameState.get_nursery_egg(GameState.get_active_egg_id())
	var species_id: String = "-"
	var stage: String = "-"
	var hunger: String = "-"
	var mood: String = "-"
	var cleanliness: String = "-"
	var health: String = "-"
	var growth_exp: String = "-"
	if not pet.is_empty():
		species_id = str(pet.get("species_id", "-"))
		stage = str(pet.get("stage", "-"))
		hunger = str(pet.get("hunger", "-"))
		mood = str(pet.get("mood", "-"))
		cleanliness = str(GameState.get_aquarium().get("cleanliness", "-"))
		health = str(pet.get("health", "-"))
		growth_exp = str(pet.get("growth_exp", "-"))
	elif not egg.is_empty():
		species_id = str(egg.get("species_id", "-"))
	var lines: Array = [
		"版本：%s" % VersionManager.get_display_text(),
		"目前場景：%s" % SceneRouter.current_scene_path,
		"選取寵物：%s（%s）" % [pet_id, str(pet.get("personality_id", "-"))],
		"同住寵物：%s" % str(GameState.get_active_pet_ids()),
		"物種代碼：%s" % species_id,
		"階段：%s" % stage,
		"飢餓：%s" % hunger,
		"心情：%s" % mood,
		"清潔度：%s" % cleanliness,
		"健康：%s" % health,
		"成長經驗：%s" % growth_exp,
		"泡泡幣：%d" % GameState.get_currency("bubble_coin"),
		"飼料：∞",
		"餅乾：%d" % GameState.get_inventory_count("cookie_basic"),
		"存檔路徑：%s" % SaveManager.get_save_path(),
		"最後存檔時間：%s" % GameState.get_timestamp("last_saved_at")
	]
	info_label.text = "\n".join(lines)
