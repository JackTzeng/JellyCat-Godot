extends Node

const ISOLATED_SAVE_PATH: String = "user://jellycat_g1_gameplay_save.json"
const DOS_STYLE = preload("res://scripts/ui/dos_style.gd")

var checks: int = 0
var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	print("G1 acceptance: start")
	_expect(SaveManager.set_save_path_for_test(ISOLATED_SAVE_PATH), "Uses a separate user:// save file")
	SaveManager.reset_save()
	GameApp.load_data_tables()
	GameState.reset_to_default()
	var title_scene: PackedScene = load("res://scenes/title/title.tscn") as PackedScene
	_expect(title_scene != null, "Real Title scene loads")
	if title_scene != null:
		var title_ui: Control = title_scene.instantiate() as Control
		get_tree().root.add_child(title_ui)
		await get_tree().process_frame
		var new_game_button: Button = title_ui.get_node("%NewGameButton") as Button
		_expect(new_game_button.pressed.is_connected(Callable(title_ui, "_on_new_game_pressed")), "Title New Game button binds to its handler")
		_expect(new_game_button.get_theme_stylebox("normal") != null, "Title button receives the DOS-style flat control")
		title_ui.queue_free()
		await get_tree().process_frame
	var starter_eggs: Array[Dictionary] = EggSystem.ensure_starter_eggs()
	_expect(starter_eggs.size() == 3, "New game grants three starter eggs")
	var egg_select_scene: PackedScene = load("res://scenes/egg_select/egg_select.tscn") as PackedScene
	var egg_select_ui: Control = egg_select_scene.instantiate() as Control
	get_tree().root.add_child(egg_select_ui)
	await get_tree().process_frame
	_expect(bool(egg_select_ui.call("_select_active_egg")), "The starter egg can be selected through the Egg Select UI")
	egg_select_ui.queue_free()
	await get_tree().process_frame
	var hatch_scene: PackedScene = load("res://scenes/hatch/hatch.tscn") as PackedScene
	var aquarium_scene: PackedScene = load("res://scenes/aquarium/aquarium.tscn") as PackedScene
	var aquarium: Control = null
	for hatch_index in range(3):
		if hatch_index > 0:
			_expect(aquarium != null and not (aquarium.get_node("%NurseryButton") as Button).disabled, "The Aquarium offers remaining starter eggs in its Nursery button")
			_expect(bool(aquarium.call("_select_next_unhatched_egg")), "Nursery selects the next unhatched egg by ID")
		var hatch_ui: Control = hatch_scene.instantiate() as Control
		get_tree().root.add_child(hatch_ui)
		await get_tree().process_frame
		var egg_button: Button = hatch_ui.get_node("%EggButton") as Button
		for _tap in range(10):
			egg_button.pressed.emit()
		_expect(GameState.get_active_pet_ids().size() == hatch_index + 1, "Hatch UI adds pet %d through 10 player taps" % (hatch_index + 1))
		if hatch_index == 0:
			aquarium = aquarium_scene.instantiate() as Control
			get_tree().root.add_child(aquarium)
		hatch_ui.queue_free()
		await get_tree().process_frame
	for pet_id in GameState.get_active_pet_ids():
		var pet: Dictionary = GameState.get_pet(pet_id)
		pet["hunger"] = 35
		GameState.set_pet(pet_id, pet)

	_expect(aquarium_scene != null, "Real Aquarium scene loads")
	if aquarium_scene == null:
		_finish()
		return
	await get_tree().process_frame
	print("G1 acceptance: aquarium and three actors ready")
	var actors: Dictionary = aquarium.get("actors_by_id") as Dictionary
	_expect(actors.size() == 3, "Aquarium creates three pet actors")
	var actor_anchor: Node2D = aquarium.get_node("%ActorAnchor") as Node2D
	_expect(actor_anchor.get_child_count() == 3, "Actor scene tree has exactly three children")
	var coin_container: Control = aquarium.get_node("%CoinBubbleContainer") as Control
	var food_container: Control = aquarium.get_node("%FoodDropContainer") as Control
	var status_backdrop: Control = aquarium.get_node("%StatusBackdrop") as Control
	var action_layer: Control = aquarium.get_node("%ActionBar") as Control
	var water_background: Control = aquarium.get_node("%Water") as Control
	var overlay_layer: Control = aquarium.get_node("%ModalOverlay") as Control
	var modal_input_shield: ColorRect = aquarium.get_node("%ModalInputShield") as ColorRect
	var native_tank_script: Script = load("res://scripts/ui/native_tank.gd") as Script
	var stage_sprite: Sprite2D = null
	var current_pet_ids: Array[String] = GameState.get_active_pet_ids()
	if not current_pet_ids.is_empty():
		var first_stage_actor: Node = actors.get(current_pet_ids[0]) as Node
		if first_stage_actor != null:
			stage_sprite = first_stage_actor.get_node("%Sprite") as Sprite2D
	_expect(water_background.get_script() == native_tank_script and water_background.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Native DOS tank replaces the soft background and ignores input")
	_expect(stage_sprite != null and stage_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Official 64-pixel stage art uses nearest-neighbor sampling")
	_expect(overlay_layer.get_index() > action_layer.get_index() and overlay_layer.mouse_filter == Control.MOUSE_FILTER_IGNORE and modal_input_shield.mouse_filter == Control.MOUSE_FILTER_STOP and overlay_layer.get_index() + 1 == aquarium.get_child_count() and aquarium.get_node("%ShopPanel").get_parent() == overlay_layer and aquarium.get_node("%ShopPanel").get_index() > modal_input_shield.get_index(), "Modal shield and Shop sit above the HUD in input-safe order")
	_expect(not (aquarium.get_node("%RuntimeLogPanel") as Control).visible and (aquarium.get_node("%LogToggleButton") as Button).visible == OS.is_debug_build(), "Runtime log starts hidden and is explicitly available only in debug builds")
	var pet_info_button: Button = aquarium.get("pet_info_button") as Button
	var coin_label: Label = aquarium.get_node("%CoinLabel") as Label
	var inventory_label: Label = aquarium.get_node("%InventoryLabel") as Label
	var pet_details_collapsed: bool = not bool(aquarium.get("pet_info_open")) and pet_info_button != null and pet_info_button.text == "Pet Info"
	pet_details_collapsed = pet_details_collapsed and status_backdrop.visible and coin_label.visible and coin_label.text.begins_with("Coin:")
	pet_details_collapsed = pet_details_collapsed and not (aquarium.get_node("%StageLabel") as Control).visible and inventory_label.visible and inventory_label.text.contains("Food x")
	_expect(pet_details_collapsed, "Aquarium starts with compact coin and inventory status while individual details stay closed")
	var world_is_below_hud: bool = aquarium.get_node("%Water").get_index() < actor_anchor.get_index()
	world_is_below_hud = world_is_below_hud and actor_anchor.get_index() < food_container.get_index() and food_container.get_index() < coin_container.get_index()
	world_is_below_hud = world_is_below_hud and coin_container.get_index() < status_backdrop.get_index() and coin_container.get_index() < action_layer.get_index()
	world_is_below_hud = world_is_below_hud and aquarium.mouse_filter == Control.MOUSE_FILTER_IGNORE and (aquarium.get_node("%Water") as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE
	world_is_below_hud = world_is_below_hud and (aquarium.get_node("%FeedButton") as Button).mouse_filter == Control.MOUSE_FILTER_STOP
	_expect(world_is_below_hud, "Aquarium draw order puts HUD above coins, pets, food, and water")
	var viewport_16_9: Vector2 = Vector2(1280.0, 720.0)
	var safe_16_9: Rect2 = Rect2(Vector2(24.0, 12.0), Vector2(1232.0, 696.0))
	aquarium.call("_layout_ui", viewport_16_9, safe_16_9)
	var water_16_9: Rect2 = aquarium.get("active_water_rect")
	var water_inside_safe_16_9: bool = water_16_9.position.x >= safe_16_9.position.x and water_16_9.position.y >= safe_16_9.position.y
	water_inside_safe_16_9 = water_inside_safe_16_9 and water_16_9.end.x <= safe_16_9.end.x and water_16_9.end.y <= safe_16_9.end.y
	var ui_nodes: Array[Control] = [
		status_backdrop,
		aquarium.get_node("%InventoryBackdrop") as Control,
		aquarium.get_node("%PetRosterBackdrop") as Control,
		aquarium.get_node("%MessageLabel") as Control,
		aquarium.get_node("%ActionBackdrop") as Control,
		aquarium.get_node("%RuntimeLogPanel") as Control,
		aquarium.get_node("%ShopPanel") as Control,
	]
	var water_clear_of_visible_ui: bool = true
	var ui_inside_safe: bool = true
	var ui_layout_diagnostics: Array[String] = []
	for ui_node in ui_nodes:
		var ui_rect: Rect2 = Rect2(ui_node.position, ui_node.size)
		if ui_node.is_visible_in_tree():
			water_clear_of_visible_ui = water_clear_of_visible_ui and not water_16_9.intersects(ui_rect)
		ui_inside_safe = ui_inside_safe and ui_rect.position.x >= safe_16_9.position.x and ui_rect.position.y >= safe_16_9.position.y
		ui_inside_safe = ui_inside_safe and ui_rect.end.x <= safe_16_9.end.x and ui_rect.end.y <= safe_16_9.end.y
		ui_layout_diagnostics.append("%s visible=%s rect=%s" % [ui_node.name, str(ui_node.is_visible_in_tree()), str(ui_rect)])
	var water_share_16_9: float = water_16_9.size.x * water_16_9.size.y / (safe_16_9.size.x * safe_16_9.size.y)
	print("G1 layout 16:9 safe=%s water=%s share=%.3f safe_fit=%s visible_disjoint=%s controls=%s" % [str(safe_16_9), str(water_16_9), water_share_16_9, str(water_inside_safe_16_9 and ui_inside_safe), str(water_clear_of_visible_ui), str(ui_layout_diagnostics)])
	_expect(water_inside_safe_16_9 and water_clear_of_visible_ui and ui_inside_safe, "16:9 active water and visible HUD stay inside safe insets without covering the water")
	_expect(water_share_16_9 >= 0.45, "Default 16:9 water remains at least 45% of the safe area with log and shop closed")
	await get_tree().create_timer(0.4).timeout
	var all_bodies_fit_16_9: bool = true
	var all_stage_one_ratios_fit: bool = true
	for pet_id in GameState.get_active_pet_ids():
		var actor: Node = actors.get(pet_id) as Node
		var body_rect: Rect2 = actor.call("get_visual_body_rect_global")
		all_bodies_fit_16_9 = all_bodies_fit_16_9 and body_rect.position.x >= water_16_9.position.x and body_rect.position.y >= water_16_9.position.y
		all_bodies_fit_16_9 = all_bodies_fit_16_9 and body_rect.end.x <= water_16_9.end.x and body_rect.end.y <= water_16_9.end.y
		var body_size: Vector2 = actor.call("get_visual_body_size")
		var body_ratio: float = body_size.y / water_16_9.size.y
		all_stage_one_ratios_fit = all_stage_one_ratios_fit and body_ratio >= 0.15 and body_ratio <= 0.20
	_expect(all_bodies_fit_16_9 and all_stage_one_ratios_fit, "Three stage-one bodies stay visible at 15–20% of 16:9 water height")
	var visual_probe: Node = actors.get(GameState.get_active_pet_ids()[0]) as Node
	var prior_stage: int = int(visual_probe.get("current_stage"))
	var stages_grow_within_limit: bool = true
	var previous_body_height: float = 0.0
	for stage in range(1, 6):
		visual_probe.call("set_stage", stage, "normal_jellycat")
		var stage_body: Vector2 = visual_probe.call("get_visual_body_size")
		var animated_body: Vector2 = visual_probe.call("get_max_animated_body_size")
		var stage_rect: Rect2 = visual_probe.call("get_visual_body_rect_global")
		var stage_fits: bool = stage_rect.position.x >= water_16_9.position.x and stage_rect.position.y >= water_16_9.position.y
		stage_fits = stage_fits and stage_rect.end.x <= water_16_9.end.x and stage_rect.end.y <= water_16_9.end.y
		stages_grow_within_limit = stages_grow_within_limit and stage_body.y > previous_body_height and animated_body.y <= water_16_9.size.y * 0.25 and stage_fits
		previous_body_height = stage_body.y
	visual_probe.call("set_stage", prior_stage, "normal_jellycat")
	_expect(stages_grow_within_limit, "Five stage textures grow by visible bounds and never exceed 25% with animation")
	var probe_sprite: Sprite2D = visual_probe.get_node("%Sprite") as Sprite2D
	var actor_touch_target: float = DOS_STYLE.get_touch_target_height(aquarium.get_viewport_rect().size)
	var visible_pixel_rect: Rect2 = visual_probe.call("_get_texture_content_rect")
	var touch_probe_local: Vector2 = visible_pixel_rect.get_center() + Vector2(visible_pixel_rect.size.x * 0.5 + actor_touch_target * 0.49 / maxf(float(visual_probe.get("base_scale")), 0.001), 0.0)
	var touch_probe_screen: Vector2 = probe_sprite.to_global(touch_probe_local)
	var low_resolution_hitbox_kept: bool = bool(visual_probe.call("contains_screen_point", touch_probe_screen, actor_touch_target))
	_expect(low_resolution_hitbox_kept, "Pet hit area stays at the 56dp viewport-scaled target outside the pixel body")
	var probe_base_scale: float = float(visual_probe.get("base_scale"))
	visual_probe.set("food_drop_id", "visual-scale-probe")
	visual_probe.set("behavior_state", "eat")
	visual_probe.call("_process", 0.1)
	var eating_keeps_base: bool = probe_sprite.scale.x >= probe_base_scale * 0.95 and probe_sprite.scale.x <= probe_base_scale * 1.05
	visual_probe.call("clear_food_target", "visual-scale-probe")
	var cancel_keeps_base: bool = is_equal_approx(probe_sprite.scale.x, probe_base_scale)
	visual_probe.set("food_drop_id", "visual-meal-probe")
	visual_probe.call("complete_meal", "visual-meal-probe")
	var meal_keeps_base: bool = is_equal_approx(probe_sprite.scale.x, probe_base_scale)
	visual_probe.set("behavior_state", "idle_roam")
	_expect(eating_keeps_base and cancel_keeps_base and meal_keeps_base, "Eat pulse, cancel, and meal completion preserve computed base scale")
	var inventory_before_hud_tap: int = GameState.get_food_drops().size()
	var hud_tap: InputEventScreenTouch = InputEventScreenTouch.new()
	hud_tap.pressed = true
	hud_tap.position = status_backdrop.position + status_backdrop.size / 2.0
	aquarium.call("_unhandled_input", hud_tap)
	_expect(GameState.get_food_drops().size() == inventory_before_hud_tap, "HUD-area taps cannot fall through into water actions")
	aquarium.call("_layout_ui", Vector2(2400.0, 1080.0), Rect2(Vector2(40.0, 24.0), Vector2(2320.0, 1032.0)))
	var safe_20_9: Rect2 = Rect2(Vector2(40.0, 24.0), Vector2(2320.0, 1032.0))
	var water_20_9: Rect2 = aquarium.get("active_water_rect")
	var water_inside_safe_20_9: bool = water_20_9.position.x >= safe_20_9.position.x and water_20_9.position.y >= safe_20_9.position.y
	water_inside_safe_20_9 = water_inside_safe_20_9 and water_20_9.end.x <= safe_20_9.end.x and water_20_9.end.y <= safe_20_9.end.y
	var bodies_fit_20_9: bool = true
	for pet_id in GameState.get_active_pet_ids():
		var actor: Node = actors.get(pet_id) as Node
		var body_rect: Rect2 = actor.call("get_visual_body_rect_global")
		bodies_fit_20_9 = bodies_fit_20_9 and body_rect.position.x >= water_20_9.position.x and body_rect.position.y >= water_20_9.position.y
		bodies_fit_20_9 = bodies_fit_20_9 and body_rect.end.x <= water_20_9.end.x and body_rect.end.y <= water_20_9.end.y
	_expect(water_inside_safe_20_9 and bodies_fit_20_9, "20:9 active water and three actor bodies stay inside safe insets")
	var simulated_action: Control = aquarium.get_node("%ActionBar") as Control
	var simulated_roster: Control = aquarium.get_node("%PetRoster") as Control
	print("G1 layout 20:9 viewport=%s root=%s safe=%s action=%s roster=%s water=%s" % [str(Vector2(2400.0, 1080.0)), str(aquarium.size), str(safe_20_9), str(Rect2(simulated_action.position, simulated_action.size)), str(Rect2(simulated_roster.position, simulated_roster.size)), str(water_20_9)])
	_expect(simulated_action.position.x >= 40.0 and simulated_action.position.y >= 24.0 and simulated_action.position.x + simulated_action.size.x <= 2360.0 and simulated_action.position.y + simulated_action.size.y <= 1056.0, "20:9 layout keeps the action bar inside simulated safe bounds")
	_expect(simulated_roster.position.x >= 40.0 and simulated_roster.position.y >= 24.0 and simulated_roster.position.x + simulated_roster.size.x <= 2360.0, "20:9 layout keeps the pet roster inside simulated safe bounds")
	aquarium.call("_apply_responsive_layout")
	var selected_id: String = GameState.get_active_pet_ids()[0]
	GameState.set_selected_pet_id(selected_id)
	print("G1 acceptance: before roster/rename")
	var nickname_edit: LineEdit = aquarium.get_node("%NicknameEdit") as LineEdit
	var rename_button: Button = aquarium.get_node("%RenameButton") as Button
	var rename_dialog: ConfirmationDialog = aquarium.get_node("%RenameDialog") as ConfirmationDialog
	_expect(rename_dialog.confirmed.is_connected(Callable(aquarium, "_on_rename_confirmed")), "Rename dialog is connected to the selected pet")
	rename_button.pressed.emit()
	var rename_shield_active: bool = modal_input_shield.visible
	var food_before_rename_touch: int = GameState.get_food_drops().size()
	var rename_touch: InputEventScreenTouch = InputEventScreenTouch.new()
	var rename_water_rect: Rect2 = aquarium.get("active_water_rect")
	rename_touch.pressed = true
	rename_touch.position = rename_water_rect.get_center()
	aquarium.call("_unhandled_input", rename_touch)
	var rename_blocks_world: bool = GameState.get_food_drops().size() == food_before_rename_touch
	nickname_edit.text = "Mochi"
	rename_dialog.confirmed.emit()
	_expect(rename_shield_active and rename_blocks_world and not modal_input_shield.visible, "Rename modal shields world input and releases it when closed")
	_expect(str(GameState.get_pet(selected_id).get("nickname", "")) == "Mochi", "Rename dialog persists the selected pet nickname")
	_expect(str((aquarium.get_node("%EvolutionLabel") as Label).text).contains("EXP left"), "Selected pet UI shows EXP remaining to the next stage")
	var roster_buttons: Dictionary = aquarium.get("roster_buttons_by_id") as Dictionary
	var second_id: String = GameState.get_active_pet_ids()[1]
	var second_pet_button: Button = roster_buttons.get(second_id) as Button
	second_pet_button.pressed.emit()
	_expect(GameState.get_selected_pet_id() == second_id, "Roster selects the pet bound to its explicit ID")
	GameState.set_selected_pet_id(selected_id)
	var nursery_button: Button = aquarium.get_node("%NurseryButton") as Button
	_expect(nursery_button.disabled and GameState.get_nursery_eggs().is_empty(), "Nursery disables only after all three starter eggs hatch")
	_expect(nursery_button.is_connected("pressed", Callable(aquarium, "_on_nursery_pressed")), "Nursery button remains connected to its route handler")
	var roster_backdrop: Control = aquarium.get_node("%PetRosterBackdrop") as Control
	_expect(roster_backdrop.get_theme_stylebox("panel") == null or roster_backdrop.size.x > 0.0, "Roster layout retains a visible flat panel")
	aquarium.call("_apply_responsive_layout")
	await get_tree().create_timer(0.4).timeout
	print("G1 acceptance: after roster/rename paused=%s eggs=%d" % [str(get_tree().paused), GameState.get_nursery_eggs().size()])
	await _run_food_geometry_regression(aquarium, actor_anchor, actors)
	var hunger_before_by_pet: Dictionary = {}
	for pet_id in GameState.get_active_pet_ids():
		var actor: Node = actors.get(pet_id) as Node
		_expect(actor != null, "%s has an actor" % pet_id)
		if actor == null:
			continue
		_expect(str(actor.get("pet_id")) == pet_id, "%s actor has an explicit matching pet_id" % pet_id)
		_expect(int(actor.get("current_stage")) == int(GameState.get_pet(pet_id).get("stage", 0)), "%s actor uses its bound stage" % pet_id)
		var start_position: Vector2 = (actor as Node2D).global_position
		hunger_before_by_pet[pet_id] = int(GameState.get_pet(pet_id).get("hunger", 0))
		var click: InputEventScreenTouch = InputEventScreenTouch.new()
		click.pressed = true
		click.position = start_position
		var touch_active_rect: Rect2 = aquarium.get("active_water_rect")
		var touch_safe_rect: Rect2 = aquarium.call("_get_safe_viewport_rect", aquarium.get_viewport_rect().size)
		var touch_hit: bool = bool(actor.call("contains_screen_point", start_position, actor_touch_target))
		var touch_in_water: bool = touch_active_rect.has_point(start_position)
		var touch_in_safe: bool = touch_safe_rect.has_point(start_position)
		aquarium.call("_unhandled_input", click)
		print("G1 pet touch id=%s pos=%s safe=%s water=%s hit=%s selected=%s" % [pet_id, str(start_position), str(touch_in_safe), str(touch_in_water), str(touch_hit), GameState.get_selected_pet_id()])
		_expect(GameState.get_selected_pet_id() == pet_id, "Touching %s selects that pet" % pet_id)
		var old_hunger: int = int(GameState.get_pet(pet_id).get("hunger", 0))
		var old_inventory: int = GameState.get_inventory_count("food_basic")
		var actions: Dictionary = aquarium.get("last_action_time_by_name") as Dictionary
		actions["feed"] = -999999.0
		aquarium.set("last_action_time_by_name", actions)
		aquarium.call("_on_feed_pressed")
		_expect(int(GameState.get_pet(pet_id).get("hunger", 0)) == old_hunger, "Dropped food waits for an actor to eat")
		_expect(GameState.get_food_drops().size() == GameState.get_active_pet_ids().find(pet_id) + 1, "Feed button creates one persisted food token")
		_expect(GameState.get_inventory_count("food_basic") == old_inventory - 1, "One actor feed spends exactly one token")
	print("G1 acceptance: all drops placed=%d paused=%s" % [GameState.get_food_drops().size(), str(get_tree().paused)])
	var wait_time: float = 0.0
	while not GameState.get_food_drops().is_empty() and wait_time < 25.0:
		await get_tree().create_timer(0.1).timeout
		wait_time += 0.1
	_expect(GameState.get_food_drops().is_empty(), "Three food tokens are consumed once in the real Aquarium scene")
	var food_pet_diagnostics: Array[String] = []
	for pet_id in GameState.get_active_pet_ids():
		var food_actor: Node2D = actors.get(pet_id) as Node2D
		if food_actor != null:
			food_pet_diagnostics.append("%s:hunger=%d state=%s target=%s pos=%s" % [pet_id, int(GameState.get_pet(pet_id).get("hunger", 0)), str(food_actor.get("behavior_state")), str(food_actor.get("food_drop_id")), str(food_actor.global_position)])
	print("G1 acceptance: food chase wait %.1fs drops=%s claims=%s actors=%s" % [wait_time, str(GameState.get_food_drops()), str(aquarium.get("food_claims")), str(food_pet_diagnostics)])
	for pet_id in GameState.get_active_pet_ids():
		_expect(int(GameState.get_pet(pet_id).get("hunger", 0)) > int(hunger_before_by_pet.get(pet_id, 100)), "%s receives a fair feed" % pet_id)

	_expect(SaveManager.save_game(), "Three-pet Aquarium state saves to the isolated file")
	var pending_drop: Dictionary = FoodDropSystem.drop_food(actor_anchor.global_position + Vector2(140.0, 20.0))
	var pending_token: String = str(pending_drop.get("token_id", ""))
	var inventory_with_pending_drop: int = GameState.get_inventory_count("food_basic")
	var one_pet_id: String = GameState.get_active_pet_ids()[0]
	var hunger_before_pending_eat: int = int(GameState.get_pet(one_pet_id).get("hunger", 0))
	_expect(not pending_token.is_empty(), "One more food token is reserved before exit")
	_expect(SaveManager.save_game(), "Pending feed ledger is durable before simulated exit")
	GameState.reset_to_default()
	_expect(SaveManager.load_game(), "Three-pet Aquarium state reloads")
	_expect(GameState.get_active_pet_ids().size() == 3, "Reload retains the three active pet IDs")
	_expect(str(GameState.get_pet(selected_id).get("nickname", "")) == "Mochi", "Renamed pet identity survives the save reload")
	_expect(GameState.get_inventory_count("food_basic") == inventory_with_pending_drop, "Reload retains exact reserved food inventory")
	_expect(GameState.get_food_drops().size() == 1 and str(GameState.get_food_drops()[0].get("token_id", "")) == pending_token, "Reload restores an in-flight food token once")
	await get_tree().process_frame
	_expect((aquarium.get("actors_by_id") as Dictionary).size() == 3, "Reload reconciles exactly three live actors")
	_expect(FoodDropSystem.consume_food(pending_token, one_pet_id), "A restored token resolves to one explicit eater")
	_expect(not FoodDropSystem.consume_food(pending_token, one_pet_id), "A consumed token cannot be replayed")
	_expect(int(GameState.get_pet(one_pet_id).get("hunger", 0)) > hunger_before_pending_eat, "The replay attempt adds no second meal")
	_expect(GameState.get_inventory_count("food_basic") == inventory_with_pending_drop, "Consumption does not refund a spent token")
	_expect(GameState.get_food_drops().is_empty(), "Consumed token is removed from the save ledger")
	await get_tree().create_timer(0.6).timeout
	print("G1 acceptance: food restart transaction checks done")
	var inventory_before_expiry: int = GameState.get_inventory_count("food_basic")
	var expiry_water: Rect2 = aquarium.get("active_water_rect")
	var expiry_position: Vector2 = expiry_water.position + Vector2(24.0, 24.0)
	var expiring_drop: Dictionary = GameState.reserve_food_drop("food_basic", expiry_position, Time.get_unix_time_from_system() + 1.0)
	var expiring_token: String = str(expiring_drop.get("token_id", ""))
	_expect(not expiring_token.is_empty() and SaveManager.save_game(), "A short-lived food token saves before expiry")
	aquarium.call("_update_food_drops", 0.1)
	_expect((aquarium.get("food_drop_visuals") as Dictionary).has(expiring_token), "In-flight food token has a visible sinking marker")
	await get_tree().create_timer(1.2).timeout
	await get_tree().process_frame
	_expect(GameState.get_food_drops().is_empty(), "An expired food token leaves the ledger")
	_expect(GameState.get_inventory_count("food_basic") == inventory_before_expiry, "Expired food is refunded exactly once")
	_expect(not (aquarium.get("food_drop_visuals") as Dictionary).has(expiring_token), "Expired food marker is removed from the Aquarium")
	_expect(not (aquarium.get("food_claims") as Dictionary).has(expiring_token), "Expired food claim is cleared")
	var inventory_before_duplicate_tap: int = GameState.get_inventory_count("food_basic")
	var active_water: Rect2 = aquarium.get("active_water_rect")
	var water_tap: Vector2 = active_water.position + Vector2(24.0, 24.0)
	var world_touch: InputEventScreenTouch = InputEventScreenTouch.new()
	world_touch.pressed = true
	world_touch.position = water_tap
	aquarium.call("_unhandled_input", world_touch)
	var touch_drop_list: Array[Dictionary] = GameState.get_food_drops()
	var duplicate_mouse: InputEventMouseButton = InputEventMouseButton.new()
	duplicate_mouse.pressed = true
	duplicate_mouse.button_index = MOUSE_BUTTON_LEFT
	duplicate_mouse.position = water_tap
	aquarium.call("_unhandled_input", duplicate_mouse)
	_expect(touch_drop_list.size() == 1 and GameState.get_food_drops().size() == 1, "Touch plus its emulated mouse event reserves only one food token")
	if not touch_drop_list.is_empty():
		GameState.resolve_food_drop(str(touch_drop_list[0].get("token_id", "")))
		SaveManager.save_game()
		aquarium.call("_update_food_drops", 0.0)
	_expect(GameState.get_inventory_count("food_basic") == inventory_before_duplicate_tap, "Duplicate world input does not spend food twice")
	aquarium.call("_set_pet_info_open", false)
	await get_tree().create_timer(0.4).timeout
	var panel_actors_ready: bool = false
	while not panel_actors_ready:
		panel_actors_ready = true
		for pet_id in GameState.get_active_pet_ids():
			var panel_actor: Node2D = (aquarium.get("actors_by_id") as Dictionary).get(pet_id) as Node2D
			if panel_actor == null or not bool(panel_actor.call("can_accept_food")):
				panel_actors_ready = false
				break
		if not panel_actors_ready:
			await get_tree().process_frame
	_expect(panel_actors_ready, "All three actors can accept food before the panel-preservation drop")
	var panel_water: Rect2 = aquarium.get("active_water_rect")
	var panel_marker_half_size: Vector2 = Vector2(16.0, 16.0)
	var panel_drop_candidates: Array[Vector2] = [
		panel_water.position + panel_marker_half_size,
		Vector2(panel_water.end.x - panel_marker_half_size.x, panel_water.position.y + panel_marker_half_size.y),
		Vector2(panel_water.position.x + panel_marker_half_size.x, panel_water.end.y - panel_marker_half_size.y),
		panel_water.end - panel_marker_half_size,
	]
	var panel_drop_position: Vector2 = panel_water.get_center()
	var panel_drop_clearance: float = -1.0
	for candidate_position in panel_drop_candidates:
		var candidate_marker_rect: Rect2 = Rect2(candidate_position - panel_marker_half_size, panel_marker_half_size * 2.0)
		var candidate_clearance: float = INF
		var candidate_has_no_contact: bool = true
		for pet_id in GameState.get_active_pet_ids():
			var candidate_actor: Node2D = (aquarium.get("actors_by_id") as Dictionary).get(pet_id) as Node2D
			if candidate_actor == null:
				candidate_has_no_contact = false
				break
			candidate_clearance = minf(candidate_clearance, candidate_actor.global_position.distance_to(candidate_position))
			var candidate_body_rect: Rect2 = candidate_actor.call("get_visual_body_rect_global")
			if candidate_body_rect.intersects(candidate_marker_rect):
				candidate_has_no_contact = false
		if candidate_has_no_contact and candidate_clearance > panel_drop_clearance:
			panel_drop_position = candidate_position
			panel_drop_clearance = candidate_clearance
	_expect(panel_drop_clearance >= 0.0, "Panel-preservation drop point is remote from every visible actor body")
	var panel_drop: Dictionary = FoodDropSystem.drop_food(panel_drop_position)
	var panel_drop_token: String = str(panel_drop.get("token_id", ""))
	_expect(not panel_drop_token.is_empty(), "Panel-preservation food drop reserves one token")
	aquarium.call("_update_food_drops", 0.0)
	var panel_target_pet_id: String = str((aquarium.get("food_claims") as Dictionary).get(panel_drop_token, ""))
	var panel_claim_actor: Node2D = (aquarium.get("actors_by_id") as Dictionary).get(panel_target_pet_id) as Node2D
	var panel_marker: Control = (aquarium.get("food_drop_visuals") as Dictionary).get(panel_drop_token) as Control
	var panel_actor_diagnostics: Array[String] = []
	for pet_id in GameState.get_active_pet_ids():
		var panel_actor: Node2D = (aquarium.get("actors_by_id") as Dictionary).get(pet_id) as Node2D
		panel_actor_diagnostics.append("%s:ready=%s state=%s target=%s hunger=%d" % [
			pet_id,
			str(panel_actor != null and bool(panel_actor.call("can_accept_food"))),
			"missing" if panel_actor == null else str(panel_actor.get("behavior_state")),
			"missing" if panel_actor == null else str(panel_actor.get("food_drop_id")),
			int(GameState.get_pet(pet_id).get("hunger", -1)),
		])
	print("G1 panel-preservation claim diagnostic: token=%s target_pet=%s claims=%s drops=%s actors=%s" % [
		panel_drop_token,
		panel_target_pet_id,
		str(aquarium.get("food_claims")),
		str(GameState.get_food_drops()),
		str(panel_actor_diagnostics),
	])
	var panel_claim_established: bool = not panel_target_pet_id.is_empty() and panel_claim_actor != null
	panel_claim_established = panel_claim_established and str(panel_claim_actor.get("food_drop_id")) == panel_drop_token
	panel_claim_established = panel_claim_established and str(panel_claim_actor.get("behavior_state")) == "approach_food"
	panel_claim_established = panel_claim_established and panel_marker != null
	_expect(panel_claim_established, "Panel-preservation drop starts a real chase with its target established before snapshot")
	var actor_instances_before_panels: Dictionary = {}
	var actor_layout_before_panels: Dictionary = {}
	for pet_id in GameState.get_active_pet_ids():
		var panel_actor: Node2D = (aquarium.get("actors_by_id") as Dictionary).get(pet_id) as Node2D
		var panel_actor_food_drop_id: String = str(panel_actor.get("food_drop_id"))
		var panel_actor_world_target: Vector2 = actor_anchor.to_global(panel_actor.get("roam_target"))
		actor_instances_before_panels[pet_id] = int(panel_actor.get_instance_id())
		actor_layout_before_panels[pet_id] = {
			"world_position": panel_actor.global_position,
			"world_target": panel_actor_world_target,
			"food_target": panel_actor_world_target if panel_actor_food_drop_id == panel_drop_token else Vector2.ZERO,
			"pet_id": str(panel_actor.get("pet_id")),
			"behavior_state": str(panel_actor.get("behavior_state")),
			"food_drop_id": panel_actor_food_drop_id,
		}
	var actions_before_panels: Dictionary = aquarium.get("last_action_time_by_name") as Dictionary
	actions_before_panels["shop"] = -999999.0
	actions_before_panels["log_toggle"] = -999999.0
	aquarium.set("last_action_time_by_name", actions_before_panels)
	var runtime_log_panel: Control = aquarium.get_node("%RuntimeLogPanel") as Control
	var shop_panel: Control = aquarium.get_node("%ShopPanel") as Control
	var info_open_preserved_world: bool = not panel_target_pet_id.is_empty()
	if not panel_target_pet_id.is_empty():
		aquarium.call("_on_pet_roster_pressed", panel_target_pet_id)
		var chase_actor: Node2D = (aquarium.get("actors_by_id") as Dictionary).get(panel_target_pet_id) as Node2D
		var before_state: Dictionary = actor_layout_before_panels[panel_target_pet_id]
		info_open_preserved_world = bool(aquarium.get("pet_info_open")) and chase_actor != null
		info_open_preserved_world = info_open_preserved_world and int(chase_actor.get_instance_id()) == int(actor_instances_before_panels[panel_target_pet_id])
		info_open_preserved_world = info_open_preserved_world and str(chase_actor.get("pet_id")) == str(before_state.get("pet_id"))
		info_open_preserved_world = info_open_preserved_world and str(chase_actor.get("behavior_state")) == str(before_state.get("behavior_state"))
		info_open_preserved_world = info_open_preserved_world and str(chase_actor.get("food_drop_id")) == str(before_state.get("food_drop_id"))
		info_open_preserved_world = info_open_preserved_world and chase_actor.global_position.distance_to(before_state.get("world_position")) <= 0.5
		info_open_preserved_world = info_open_preserved_world and actor_anchor.to_global(chase_actor.get("roam_target")).distance_to(before_state.get("world_target")) <= 0.5
		info_open_preserved_world = info_open_preserved_world and actor_anchor.to_global(chase_actor.get("roam_target")).distance_to(before_state.get("food_target")) <= 0.5
		if not info_open_preserved_world:
			print("G1 panel-open preservation diagnostic: pet=%s actor=%s before=%s after_position=%s after_target=%s" % [
				panel_target_pet_id,
				str(chase_actor),
				str(before_state),
				"missing" if chase_actor == null else str(chase_actor.global_position),
				"missing" if chase_actor == null else str(actor_anchor.to_global(chase_actor.get("roam_target"))),
			])
	else:
		print("G1 panel-open preservation diagnostic: no feed-ready actor for token=%s claims=%s" % [panel_drop_token, str(aquarium.get("food_claims"))])
	_expect(info_open_preserved_world, "Selecting a pet opens its details without replacing its actor or moving its position/food target/behavior phase")
	var info_close_preserved_world: bool = not panel_target_pet_id.is_empty()
	if not panel_target_pet_id.is_empty():
		var chase_actor_before_close: Node2D = (aquarium.get("actors_by_id") as Dictionary).get(panel_target_pet_id) as Node2D
		var before_state: Dictionary = actor_layout_before_panels[panel_target_pet_id]
		var close_position_before: Vector2 = chase_actor_before_close.global_position
		var close_target_before: Vector2 = actor_anchor.to_global(chase_actor_before_close.get("roam_target"))
		aquarium.call("_set_pet_info_open", false)
		var chase_actor_after_close: Node2D = (aquarium.get("actors_by_id") as Dictionary).get(panel_target_pet_id) as Node2D
		info_close_preserved_world = not bool(aquarium.get("pet_info_open")) and chase_actor_after_close != null
		info_close_preserved_world = info_close_preserved_world and int(chase_actor_after_close.get_instance_id()) == int(actor_instances_before_panels[panel_target_pet_id])
		info_close_preserved_world = info_close_preserved_world and str(chase_actor_after_close.get("pet_id")) == str(before_state.get("pet_id"))
		info_close_preserved_world = info_close_preserved_world and str(chase_actor_after_close.get("behavior_state")) == str(before_state.get("behavior_state"))
		info_close_preserved_world = info_close_preserved_world and str(chase_actor_after_close.get("food_drop_id")) == str(before_state.get("food_drop_id"))
		info_close_preserved_world = info_close_preserved_world and chase_actor_after_close.global_position.distance_to(close_position_before) <= 0.5
		info_close_preserved_world = info_close_preserved_world and actor_anchor.to_global(chase_actor_after_close.get("roam_target")).distance_to(close_target_before) <= 0.5
		info_close_preserved_world = info_close_preserved_world and actor_anchor.to_global(chase_actor_after_close.get("roam_target")).distance_to(before_state.get("food_target")) <= 0.5
	_expect(info_close_preserved_world, "Closing pet details preserves the actor, position, food target and behavior phase")
	await get_tree().create_timer(0.4).timeout
	var log_was_open: bool = false
	if OS.is_debug_build():
		(aquarium.get_node("%LogToggleButton") as Button).pressed.emit()
		log_was_open = runtime_log_panel.visible
	aquarium.call("_on_shop_pressed")
	var modal_food_before: int = GameState.get_food_drops().size()
	var modal_touch: InputEventScreenTouch = InputEventScreenTouch.new()
	var modal_water_rect: Rect2 = aquarium.get("active_water_rect")
	modal_touch.pressed = true
	modal_touch.position = modal_water_rect.get_center()
	aquarium.call("_unhandled_input", modal_touch)
	_expect(shop_panel.visible and not runtime_log_panel.visible and modal_input_shield.visible and (not OS.is_debug_build() or log_was_open) and GameState.get_food_drops().size() == modal_food_before, "Shop closes the debug log and blocks background water input")
	var close_shop_button: Button = shop_panel.get_node("%CloseShopButton") as Button
	close_shop_button.pressed.emit()
	_expect(not shop_panel.visible and not modal_input_shield.visible and not runtime_log_panel.visible and RuntimeLogger.get_log_text().contains("Shop clicked"), "Closing Shop restores the aquarium and preserves hidden log contents")
	var actor_instances_after_panels: Dictionary = aquarium.get("actors_by_id") as Dictionary
	var actors_stayed_live: bool = true
	for pet_id in actor_instances_before_panels.keys():
		actors_stayed_live = actors_stayed_live and int(actor_instances_after_panels[pet_id].get_instance_id()) == int(actor_instances_before_panels[pet_id])
	_expect(actors_stayed_live, "Opening Shop and runtime panels keeps each actor instance alive")
	_expect((aquarium.get("food_drop_visuals") as Dictionary).has(panel_drop_token) and not GameState.get_food_drops().is_empty(), "Opening panels leaves an in-flight food token visible")
	if not panel_drop_token.is_empty():
		FoodDropSystem.consume_food(panel_drop_token, GameState.get_selected_pet_id())
		aquarium.call("_update_food_drops", 0.0)

	var source_pet_id: String = GameState.get_active_pet_ids()[0]
	var source_actor: Node2D = (aquarium.get("actors_by_id") as Dictionary).get(source_pet_id) as Node2D
	var source_pet: Dictionary = GameState.get_pet(source_pet_id)
	source_pet["mood"] = 100
	GameState.set_pet(source_pet_id, source_pet)
	var balance_table: Dictionary = GameApp.get_table("balance")
	balance_table["coin_bubble_auto_collect_seconds"] = 1.0
	GameApp.data_tables["balance"] = balance_table
	var coin_before: int = GameState.get_currency("bubble_coin")
	var source_coin_position: Vector2 = CoinDropSystem.get_spawn_position(aquarium.get_viewport_rect().size, source_actor.global_position)
	var manual_coin: Dictionary = CoinDropSystem.reserve_coin(source_pet_id, 3, source_coin_position)
	var manual_token: String = str(manual_coin.get("token_id", ""))
	var reserved_coin_position: Vector2 = Vector2(float(manual_coin.get("x", -999.0)), float(manual_coin.get("y", -999.0)))
	_expect(not manual_token.is_empty() and reserved_coin_position.distance_to(source_actor.global_position) <= 80.0, "Coin is durably reserved near its source pet")
	aquarium.call("_add_coin_bubble", manual_coin)
	var manual_bubble: Node = (aquarium.get("coin_bubbles_by_id") as Dictionary).get(manual_token) as Node
	_expect(manual_bubble != null, "Reserved coin restores as a visible pickup")
	if manual_bubble != null:
		manual_bubble.call("collect", false)
		manual_bubble.call("collect", false)
	_expect(GameState.get_currency("bubble_coin") == coin_before + 3, "Manual pickup credits once before the wallet animation")
	_expect(GameState.get_coin_drops().is_empty(), "Collected coin is removed from its durable ledger")
	_expect(CoinDropSystem.collect_coin(manual_token, false).is_empty(), "A collected coin token cannot be replayed")
	_expect(GameState.get_currency("bubble_coin") == coin_before + 3, "Replay does not credit a second coin")
	print("G1 acceptance: manual coin settlement done")
	_expect(SaveManager.save_game(), "Manual coin result is durable before simulated exit")
	GameState.reset_to_default()
	_expect(SaveManager.load_game(), "Manual coin state reloads from its isolated save file")
	aquarium.queue_free()
	await get_tree().process_frame
	aquarium = aquarium_scene.instantiate() as Control
	get_tree().root.add_child(aquarium)
	await get_tree().process_frame
	_expect((aquarium.get("coin_bubbles_by_id") as Dictionary).is_empty(), "Restart does not restore a settled coin")
	_expect(GameState.get_currency("bubble_coin") == coin_before + 3, "Restart retains exactly one manual credit")
	print("G1 acceptance: manual coin restart done")

	var restored_source_actor: Node2D = (aquarium.get("actors_by_id") as Dictionary).get(source_pet_id) as Node2D
	var pending_coin: Dictionary = CoinDropSystem.reserve_coin(source_pet_id, 2, restored_source_actor.global_position)
	var pending_coin_token: String = str(pending_coin.get("token_id", ""))
	_expect(not pending_coin_token.is_empty(), "A second coin token is reserved before exit")
	GameState.reset_to_default()
	_expect(SaveManager.load_game(), "Pending coin ledger reloads from its isolated save file")
	aquarium.queue_free()
	await get_tree().process_frame
	aquarium = aquarium_scene.instantiate() as Control
	get_tree().root.add_child(aquarium)
	await get_tree().process_frame
	_expect((aquarium.get("coin_bubbles_by_id") as Dictionary).has(pending_coin_token), "Restart restores one uncollected coin")
	var coin_before_auto: int = GameState.get_currency("bubble_coin")
	await get_tree().create_timer(1.2).timeout
	_expect(GameState.get_currency("bubble_coin") == coin_before_auto + 2, "Expired restored coin auto-collects once")
	_expect(GameState.get_coin_drops().is_empty(), "Auto-collection settles and removes the coin ledger entry")
	print("G1 acceptance: auto coin settlement done")
	SaveManager.reset_save()
	SaveManager.use_production_save_path()
	aquarium.queue_free()
	await get_tree().process_frame
	_finish()


func _run_food_geometry_regression(aquarium: Control, actor_anchor: Node2D, actors: Dictionary) -> void:
	var pet_ids: Array[String] = GameState.get_active_pet_ids()
	_expect(pet_ids.size() == 3, "Food geometry regression starts with three active actors")
	_expect(GameState.get_food_drops().is_empty(), "Food geometry regression starts with an empty feed ledger")
	if pet_ids.size() != 3 or not GameState.get_food_drops().is_empty():
		return

	var baseline_pets: Dictionary = {}
	for pet_id in pet_ids:
		baseline_pets[pet_id] = GameState.get_pet(pet_id)
	var baseline_inventory: int = GameState.get_inventory_count("food_basic")
	var test_case_count: int = 22
	GameState.set_inventory_count("food_basic", baseline_inventory + test_case_count)
	var original_viewport: Vector2 = aquarium.get_viewport_rect().size
	var original_safe: Rect2 = aquarium.call("_get_safe_viewport_rect", original_viewport)
	var original_info_open: bool = bool(aquarium.get("pet_info_open"))
	var original_passive_timer: float = float(aquarium.get("passive_timer"))
	aquarium.set("passive_timer", -1000.0)
	aquarium.call("_set_pet_info_open", false)

	var layouts: Array[Dictionary] = [
		{"name": "16:9", "viewport": Vector2(1280.0, 720.0), "safe": Rect2(Vector2(24.0, 12.0), Vector2(1232.0, 696.0))},
		{"name": "20:9", "viewport": Vector2(2400.0, 1080.0), "safe": Rect2(Vector2(40.0, 24.0), Vector2(2320.0, 1032.0))},
	]
	var corners: Array[String] = ["top-left", "top-right", "bottom-left", "bottom-right"]
	var matrix_case_index: int = 0

	var remote_layout: Dictionary = layouts[1]
	aquarium.call("_layout_ui", remote_layout["viewport"], remote_layout["safe"])
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	await _run_food_remote_case(
		aquarium,
		actor_anchor,
		actors.get(pet_ids[0]) as Node2D,
		pet_ids[0],
		baseline_pets[pet_ids[0]],
		remote_layout
	)

	for layout in layouts:
		aquarium.call("_layout_ui", layout["viewport"], layout["safe"])
		await get_tree().process_frame
		await get_tree().create_timer(0.4).timeout
		for stage_value in [1, 5]:
			var stage: int = int(stage_value)
			var water: Rect2 = aquarium.get("active_water_rect")
			for corner in corners:
				var raw_position: Vector2 = water.position
				match corner:
					"top-right":
						raw_position = Vector2(water.end.x, water.position.y)
					"bottom-left":
						raw_position = Vector2(water.position.x, water.end.y)
					"bottom-right":
						raw_position = water.end
				var pet_id: String = pet_ids[matrix_case_index % pet_ids.size()]
				await _run_food_contact_case(
					aquarium,
					actor_anchor,
					actors.get(pet_id) as Node2D,
					pet_id,
					baseline_pets[pet_id],
					stage,
					"%s stage %d %s" % [str(layout["name"]), stage, corner],
					raw_position,
					false
				)
				matrix_case_index += 1

			water = aquarium.get("active_water_rect")
			var floor_pet_id: String = pet_ids[matrix_case_index % pet_ids.size()]
			await _run_food_contact_case(
				aquarium,
				actor_anchor,
				actors.get(floor_pet_id) as Node2D,
				floor_pet_id,
				baseline_pets[floor_pet_id],
				stage,
				"%s stage %d fully-sunk floor" % [str(layout["name"]), stage],
				Vector2(water.get_center().x, water.position.y + 20.0),
				true
			)
			matrix_case_index += 1

	var chase_layout: Dictionary = layouts[0]
	aquarium.call("_layout_ui", chase_layout["viewport"], chase_layout["safe"])
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	await _run_food_panel_chase_case(
		aquarium,
		actor_anchor,
		actors.get(pet_ids[1]) as Node2D,
		pet_ids[1],
		baseline_pets[pet_ids[1]],
		chase_layout
	)

	for pet_id in pet_ids:
		GameState.set_pet(pet_id, baseline_pets[pet_id])
		var actor: Node2D = actors.get(pet_id) as Node2D
		if actor != null:
			actor.call("refresh_pet")
	GameState.set_inventory_count("food_basic", baseline_inventory)
	aquarium.set("passive_timer", original_passive_timer)
	SaveManager.save_game()
	if original_info_open:
		aquarium.call("_set_pet_info_open", true)
	aquarium.call("_layout_ui", original_viewport, original_safe)
	await get_tree().create_timer(0.4).timeout
	for pet_id in pet_ids:
		var actor: Node2D = actors.get(pet_id) as Node2D
		var ready_wait: float = 0.0
		while actor != null and not bool(actor.call("can_accept_food")) and ready_wait < 3.0:
			await get_tree().create_timer(0.1).timeout
			ready_wait += 0.1
		_expect(actor != null and bool(actor.call("can_accept_food")), "%s returns to feeding-ready state after geometry fixtures" % pet_id)
	print("G1 food geometry regression: callbacks=%d layouts=16:9,20:9 stages=1,5 corners=4 floor=4 remote=1 panel-chase=1" % test_case_count)


func _run_food_contact_case(
	aquarium: Control,
	actor_anchor: Node2D,
	actor: Node2D,
	pet_id: String,
	baseline_pet: Dictionary,
	stage: int,
	label: String,
	raw_position: Vector2,
	sink_to_floor: bool
) -> void:
	var ready_wait: float = 0.0
	while actor != null and not bool(actor.call("can_accept_food")) and ready_wait < 3.0:
		await get_tree().create_timer(0.1).timeout
		ready_wait += 0.1
	if actor == null or not bool(actor.call("can_accept_food")):
		_expect(false, "%s actor is ready for a geometry feed" % label)
		return

	var test_pet: Dictionary = baseline_pet.duplicate(true)
	test_pet["hunger"] = 35
	GameState.set_pet(pet_id, test_pet)
	actor.call("refresh_pet")
	actor.call("set_stage", stage, str(test_pet.get("species_id", "normal_jellycat")))
	var inventory_before: int = GameState.get_inventory_count("food_basic")
	var growth_exp_before: int = int(test_pet.get("growth_exp", 0))
	var expected_food_exp: int = int(GameApp.get_table("items").get("food_basic", {}).get("growth_exp_add", 0))
	var drop: Dictionary = aquarium.call("_drop_basic_food", raw_position, pet_id)
	var token_id: String = str(drop.get("token_id", ""))
	_expect(not token_id.is_empty(), "%s reserves one regression feed" % label)
	if token_id.is_empty():
		GameState.set_pet(pet_id, baseline_pet)
		actor.call("refresh_pet")
		return

	aquarium.call("_update_food_drops", 0.0)
	var visuals: Dictionary = aquarium.get("food_drop_visuals")
	var marker: Control = visuals.get(token_id) as Control
	_expect(marker is Panel and marker.size == Vector2(32.0, 32.0), "%s uses the fixed native food marker" % label)
	if marker == null:
		_clear_food_regression_token(aquarium, actor, token_id)
		GameState.set_pet(pet_id, baseline_pet)
		actor.call("refresh_pet")
		return

	var water: Rect2 = aquarium.get("active_water_rect")
	var marker_half: Vector2 = Vector2(16.0, 16.0)
	var expected_center: Vector2 = Vector2(
		clampf(raw_position.x, water.position.x + marker_half.x, water.end.x - marker_half.x),
		clampf(raw_position.y, water.position.y + marker_half.y, water.end.y - marker_half.y)
	)
	var marker_center: Vector2 = marker.global_position + marker.size / 2.0
	_expect(marker_center.distance_to(expected_center) <= 0.5, "%s chases the clamped marker center" % label)
	if sink_to_floor:
		aquarium.call("_update_food_drops", 60.0)
		marker_center = marker.global_position + marker.size / 2.0
		water = aquarium.get("active_water_rect")
		_expect(absf(marker.global_position.y + marker.size.y - water.end.y) <= 0.5, "%s keeps the fully-sunk marker inside the floor" % label)
	var marker_rect: Rect2 = Rect2(marker.global_position, marker.size)
	var fully_inside_water: bool = marker_rect.position.x >= water.position.x - 0.5 and marker_rect.position.y >= water.position.y - 0.5
	fully_inside_water = fully_inside_water and marker_rect.end.x <= water.end.x + 0.5 and marker_rect.end.y <= water.end.y + 0.5
	_expect(fully_inside_water, "%s keeps the entire marker inside the active water" % label)
	_expect(str((aquarium.get("food_claims") as Dictionary).get(token_id, "")) == pet_id, "%s preserves its single actor claim" % label)

	var target_local: Vector2 = actor.get("roam_target")
	actor.position = target_local
	await get_tree().process_frame
	aquarium.call("_update_food_drops", 0.0)
	var wait_time: float = 0.0
	while not GameState.get_food_drops().is_empty() and wait_time < 1.5:
		await get_tree().create_timer(0.1).timeout
		wait_time += 0.1
	var remaining_drops: Array[Dictionary] = GameState.get_food_drops()
	var token_remains: bool = false
	for remaining in remaining_drops:
		token_remains = token_remains or str(remaining.get("token_id", "")) == token_id
	var fed_pet: Dictionary = GameState.get_pet(pet_id)
	if token_remains or int(fed_pet.get("hunger", 0)) != 65:
		var final_marker: Control = (aquarium.get("food_drop_visuals") as Dictionary).get(token_id) as Control
		var marker_rect_final: Rect2 = Rect2() if final_marker == null else Rect2(final_marker.global_position, final_marker.size)
		print("G1 food contact diagnostic: case=%s wait=%.1f actor=%s target=%s body=%s marker=%s contact=%s state=%s" % [
			label,
			wait_time,
			str(actor.global_position),
			str(actor_anchor.to_global(actor.get("roam_target"))),
			str(actor.call("get_visual_body_rect_global")),
			str(marker_rect_final),
			str(final_marker != null and bool(aquarium.call("_actor_contacts_food", actor, final_marker))),
			str(actor.get("behavior_state")),
		])
	_expect(not token_remains, "%s completes the real eat timer and food_eaten consume callback" % label)
	_expect(int(fed_pet.get("hunger", 0)) == 65, "%s grants one feed benefit" % label)
	_expect(int(fed_pet.get("growth_exp", 0)) == growth_exp_before + expected_food_exp, "%s grants the configured food EXP exactly once" % label)
	_expect(GameState.get_inventory_count("food_basic") == inventory_before - 1, "%s spends one food token" % label)
	_expect(not (aquarium.get("food_claims") as Dictionary).has(token_id), "%s clears its completed claim" % label)
	_expect(not (aquarium.get("food_drop_visuals") as Dictionary).has(token_id), "%s removes its completed marker" % label)
	if token_remains:
		_clear_food_regression_token(aquarium, actor, token_id)
	GameState.set_pet(pet_id, baseline_pet)
	actor.call("refresh_pet")
	SaveManager.save_game()


func _run_food_remote_case(
	aquarium: Control,
	actor_anchor: Node2D,
	actor: Node2D,
	pet_id: String,
	baseline_pet: Dictionary,
	layout: Dictionary
) -> void:
	var test_pet: Dictionary = baseline_pet.duplicate(true)
	test_pet["hunger"] = 35
	GameState.set_pet(pet_id, test_pet)
	actor.call("refresh_pet")
	actor.call("set_stage", 5, str(test_pet.get("species_id", "normal_jellycat")))
	var water: Rect2 = aquarium.get("active_water_rect")
	actor.position = actor_anchor.to_local(water.position + Vector2(48.0, 48.0))
	var inventory_before: int = GameState.get_inventory_count("food_basic")
	var growth_exp_before: int = int(test_pet.get("growth_exp", 0))
	var expected_food_exp: int = int(GameApp.get_table("items").get("food_basic", {}).get("growth_exp_add", 0))
	var drop: Dictionary = aquarium.call("_drop_basic_food", water.end, pet_id)
	var token_id: String = str(drop.get("token_id", ""))
	_expect(not token_id.is_empty(), "Remote-food regression reserves one feed")
	if token_id.is_empty():
		GameState.set_pet(pet_id, baseline_pet)
		actor.call("refresh_pet")
		return

	aquarium.call("_update_food_drops", 0.0)
	await get_tree().create_timer(0.65).timeout
	var drops_before_contact: Array[Dictionary] = GameState.get_food_drops()
	var remote_token_remains: bool = not drops_before_contact.is_empty() and str(drops_before_contact[0].get("token_id", "")) == token_id
	_expect(remote_token_remains, "A distant 20:9 stage-5 food marker does not award an immediate meal")
	_expect(int(GameState.get_pet(pet_id).get("hunger", 0)) == 35, "A distant marker leaves hunger unchanged before contact")

	var target_local: Vector2 = actor.get("roam_target")
	actor.position = target_local
	await get_tree().process_frame
	aquarium.call("_update_food_drops", 0.0)
	var wait_time: float = 0.0
	while not GameState.get_food_drops().is_empty() and wait_time < 1.5:
		await get_tree().create_timer(0.1).timeout
		wait_time += 0.1
	var token_remains: bool = false
	for remaining in GameState.get_food_drops():
		token_remains = token_remains or str(remaining.get("token_id", "")) == token_id
	_expect(not token_remains, "The remote regression feed completes only after visible body contact")
	_expect(int(GameState.get_pet(pet_id).get("hunger", 0)) == 65, "The remote regression feed gives one benefit after contact")
	_expect(int(GameState.get_pet(pet_id).get("growth_exp", 0)) == growth_exp_before + expected_food_exp, "The remote regression feed grants the configured EXP exactly once")
	_expect(GameState.get_inventory_count("food_basic") == inventory_before - 1, "The remote regression feed spends one token")
	_expect(not (aquarium.get("food_claims") as Dictionary).has(token_id), "The remote regression clears its claim")
	_expect(not (aquarium.get("food_drop_visuals") as Dictionary).has(token_id), "The remote regression removes its marker")
	if token_remains:
		_clear_food_regression_token(aquarium, actor, token_id)
	GameState.set_pet(pet_id, baseline_pet)
	actor.call("refresh_pet")
	SaveManager.save_game()
	print("G1 food geometry remote probe: layout=%s stage=5 token=%s remote_wait=0.65s remaining=%s" % [str(layout["name"]), token_id, str(remote_token_remains)])


func _run_food_panel_chase_case(
	aquarium: Control,
	actor_anchor: Node2D,
	actor: Node2D,
	pet_id: String,
	baseline_pet: Dictionary,
	layout: Dictionary
) -> void:
	var ready_wait: float = 0.0
	while not bool(actor.call("can_accept_food")) and ready_wait < 3.0:
		await get_tree().create_timer(0.1).timeout
		ready_wait += 0.1
	if not bool(actor.call("can_accept_food")):
		_expect(false, "Panel chase actor is ready for a geometry feed")
		return

	var test_pet: Dictionary = baseline_pet.duplicate(true)
	test_pet["hunger"] = 35
	GameState.set_pet(pet_id, test_pet)
	actor.call("refresh_pet")
	actor.call("set_stage", 1, str(test_pet.get("species_id", "normal_jellycat")))
	var water: Rect2 = aquarium.get("active_water_rect")
	var drop_position: Vector2 = water.get_center() + Vector2(160.0, 0.0)
	var inventory_before: int = GameState.get_inventory_count("food_basic")
	var growth_exp_before: int = int(test_pet.get("growth_exp", 0))
	var expected_food_exp: int = int(GameApp.get_table("items").get("food_basic", {}).get("growth_exp_add", 0))
	var drop: Dictionary = aquarium.call("_drop_basic_food", drop_position, pet_id)
	var token_id: String = str(drop.get("token_id", ""))
	_expect(not token_id.is_empty(), "Panel chase regression reserves one feed")
	if token_id.is_empty():
		GameState.set_pet(pet_id, baseline_pet)
		actor.call("refresh_pet")
		return

	aquarium.call("_update_food_drops", 0.0)
	var target_local: Vector2 = actor.get("roam_target")
	actor.position = Vector2(target_local.x - 180.0, target_local.y)
	await get_tree().create_timer(0.25).timeout
	aquarium.call("_set_pet_info_open", true)
	await get_tree().create_timer(0.2).timeout
	var open_chase_valid: bool = GameState.get_food_drops().size() == 1
	open_chase_valid = open_chase_valid and str((aquarium.get("food_claims") as Dictionary).get(token_id, "")) == pet_id
	open_chase_valid = open_chase_valid and str(actor.get("food_drop_id")) == token_id
	open_chase_valid = open_chase_valid and str(actor.get("behavior_state")) == "approach_food"
	_expect(open_chase_valid, "Opening pet details during a real chase preserves the food claim and approach phase")
	var open_marker: Control = (aquarium.get("food_drop_visuals") as Dictionary).get(token_id) as Control
	_expect(_food_marker_fits_active_water(aquarium, open_marker), "Opening pet details keeps the full food marker inside the resized water")
	aquarium.call("_set_pet_info_open", false)
	await get_tree().create_timer(0.2).timeout
	var close_chase_valid: bool = GameState.get_food_drops().size() == 1
	close_chase_valid = close_chase_valid and str((aquarium.get("food_claims") as Dictionary).get(token_id, "")) == pet_id
	close_chase_valid = close_chase_valid and str(actor.get("food_drop_id")) == token_id
	var close_chase_state: String = str(actor.get("behavior_state"))
	close_chase_valid = close_chase_valid and (close_chase_state == "approach_food" or close_chase_state == "eat")
	_expect(close_chase_valid, "Closing pet details preserves the live chase through approach or its eat timer")
	var closed_marker: Control = (aquarium.get("food_drop_visuals") as Dictionary).get(token_id) as Control
	_expect(_food_marker_fits_active_water(aquarium, closed_marker), "Closing pet details keeps the full food marker inside the resized water")
	var chase_wait: float = 0.0
	while not GameState.get_food_drops().is_empty() and chase_wait < 5.0:
		await get_tree().create_timer(0.1).timeout
		chase_wait += 0.1
	var token_remains: bool = not GameState.get_food_drops().is_empty()
	_expect(not token_remains, "The live panel-transition chase reaches the real eat callback")
	_expect(int(GameState.get_pet(pet_id).get("hunger", 0)) == 65, "The panel-transition chase grants one meal")
	_expect(int(GameState.get_pet(pet_id).get("growth_exp", 0)) == growth_exp_before + expected_food_exp, "The panel-transition chase grants the configured EXP exactly once")
	_expect(GameState.get_inventory_count("food_basic") == inventory_before - 1, "The panel-transition chase spends one token")
	_expect(not (aquarium.get("food_claims") as Dictionary).has(token_id), "The panel-transition chase clears its claim")
	_expect(not (aquarium.get("food_drop_visuals") as Dictionary).has(token_id), "The panel-transition chase removes its marker")
	if token_remains:
		_clear_food_regression_token(aquarium, actor, token_id)
	GameState.set_pet(pet_id, baseline_pet)
	actor.call("refresh_pet")
	SaveManager.save_game()
	print("G1 food geometry chase probe: layout=%s stage=1 panel_open_close=true wait=%.1fs" % [str(layout["name"]), chase_wait])


func _clear_food_regression_token(aquarium: Control, actor: Node2D, token_id: String) -> void:
	actor.call("clear_food_target", token_id)
	if GameState.resolve_food_drop(token_id):
		SaveManager.save_game()
	aquarium.call("_update_food_drops", 0.0)


func _food_marker_fits_active_water(aquarium: Control, marker: Control) -> bool:
	if marker == null:
		return false
	var water: Rect2 = aquarium.get("active_water_rect")
	var marker_rect: Rect2 = Rect2(marker.global_position, marker.size)
	return (
		marker_rect.position.x >= water.position.x - 0.5
		and marker_rect.position.y >= water.position.y - 0.5
		and marker_rect.end.x <= water.end.x + 0.5
		and marker_rect.end.y <= water.end.y + 0.5
	)


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("G1_GAMEPLAY_ACCEPTANCE_OK checks=%d" % checks)
		get_tree().quit(0)
		return
	for failure in failures:
		push_error("G1_GAMEPLAY_ACCEPTANCE_FAIL: %s" % failure)
	print("G1_GAMEPLAY_ACCEPTANCE_FAILED checks=%d failures=%d" % [checks, failures.size()])
	get_tree().quit(1)
