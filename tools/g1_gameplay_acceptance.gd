extends Node

const ISOLATED_SAVE_PATH: String = "user://jellycat_g1_gameplay_save.json"
const DOS_STYLE = preload("res://scripts/ui/dos_style.gd")
const NURSERY_SCENE: String = "res://scenes/nursery/nursery.tscn"

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
			var unhatched_slots_obvious: bool = false
			if aquarium != null:
				var visible_roster: Array[Button] = aquarium.get("roster_buttons_by_slot") as Array[Button]
				unhatched_slots_obvious = visible_roster.size() == 3
				for slot_index in range(hatch_index, visible_roster.size()):
					var unhatched_label: Label = visible_roster[slot_index].get_node("NameplateLabel") as Label
					unhatched_slots_obvious = unhatched_slots_obvious and unhatched_label.text.contains("育嬰室") and not visible_roster[slot_index].disabled
				unhatched_slots_obvious = unhatched_slots_obvious and not (aquarium.get_node("%NurseryButton") as Button).disabled
			_expect(unhatched_slots_obvious, "The Aquarium offers remaining starter eggs in the Nursery button and every empty nameplate slot")
			_expect(aquarium != null and bool(aquarium.call("_select_next_unhatched_egg")), "Nursery selects the next unhatched egg by ID")
		var hatch_ui: Control = hatch_scene.instantiate() as Control
		get_tree().root.add_child(hatch_ui)
		await get_tree().process_frame
		var egg_button: Button = hatch_ui.get_node("%EggButton") as Button
		var hatch_hint: Label = hatch_ui.get_node("%HintLabel") as Label
		_expect(hatch_hint.text.contains("輕點蛋殼") and egg_button.is_visible_in_tree() and not egg_button.disabled and egg_button.text == "◌", "Hatch entry uses Traditional-Chinese instructions and a tappable egg")
		for _tap in range(10):
			egg_button.pressed.emit()
		var pet_count_after_hatch: int = GameState.get_pet_ids().size()
		var next_egg_id: String = GameState.get_active_egg_id()
		var next_egg_clicks_before: int = int(GameState.get_nursery_egg(next_egg_id).get("current_clicks", 0))
		egg_button.pressed.emit()
		var next_egg_clicks_after: int = int(GameState.get_nursery_egg(next_egg_id).get("current_clicks", 0))
		_expect(bool(hatch_ui.get("route_pending")) and egg_button.disabled and GameState.get_pet_ids().size() == pet_count_after_hatch and GameState.get_active_egg_id() == next_egg_id and next_egg_clicks_after == next_egg_clicks_before, "A rapid post-hatch tap is blocked before it can advance the next egg")
		_expect(hatch_hint.text == "新的水母喵加入水族箱了！", "Hatch completion displays its Traditional-Chinese status")
		_expect(GameState.get_active_pet_ids().size() == hatch_index + 1, "Hatch UI adds pet %d through 10 player taps" % (hatch_index + 1))
		var old_hatch_timer: Timer = hatch_ui.get("route_timer") as Timer
		if is_instance_valid(old_hatch_timer):
			old_hatch_timer.stop()
		if hatch_index == 0:
			var nursery_scene: PackedScene = load(NURSERY_SCENE) as PackedScene
			_expect(nursery_scene != null, "Real Nursery scene loads")
			var nursery_snapshot: Dictionary = GameState.to_save_dict()
			var nursery_ui: Control = nursery_scene.instantiate() as Control
			get_tree().root.add_child(nursery_ui)
			await get_tree().process_frame
			var nursery_cards: Dictionary = nursery_ui.get("egg_cards_by_id") as Dictionary
			var egg_scroll: ScrollContainer = nursery_ui.get("egg_scroll") as ScrollContainer
			var egg_grid: GridContainer = nursery_ui.get("egg_grid") as GridContainer
			var nursery_root_nearest: bool = nursery_ui.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
			var scroll_wrapper: CenterContainer = egg_scroll.get_child(0) as CenterContainer if egg_scroll != null and egg_scroll.get_child_count() > 0 else null
			_expect(egg_scroll != null and egg_grid != null and scroll_wrapper != null and scroll_wrapper.get_child(0) == egg_grid and nursery_root_nearest, "Nursery cards sit in a scroll container and the screen uses nearest texture sampling")
			var nursery_egg_ids: Array[String] = []
			for egg in GameState.get_nursery_eggs():
				nursery_egg_ids.append(str(egg.get("egg_id", "")))
			var active_nursery_egg_id: String = GameState.get_active_egg_id()
			var other_nursery_egg_id: String = nursery_egg_ids[0] if nursery_egg_ids.size() > 0 and nursery_egg_ids[0] != active_nursery_egg_id else nursery_egg_ids[1]
			_expect(nursery_cards.size() == 2 and nursery_cards.has(active_nursery_egg_id) and nursery_cards.has(other_nursery_egg_id), "Nursery lists each of the two remaining unhatched eggs")
			var active_nursery_card: Dictionary = nursery_cards.get(active_nursery_egg_id, {}) as Dictionary
			var active_nursery_button: Button = active_nursery_card.get("button") as Button
			var active_nursery_icon: TextureRect = active_nursery_card.get("icon") as TextureRect
			var card_style: StyleBoxTexture = active_nursery_button.get_theme_stylebox("normal") as StyleBoxTexture
			var card_art_scale_integer: bool = active_nursery_icon.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
			card_art_scale_integer = card_art_scale_integer and active_nursery_icon.custom_minimum_size == Vector2(128.0, 128.0)
			card_art_scale_integer = card_art_scale_integer and active_nursery_icon.texture.get_size() == Vector2(64.0, 64.0)
			card_art_scale_integer = card_art_scale_integer and card_style != null and card_style.texture.resource_path.ends_with("nursery_card_bg_96x112.png")
			card_art_scale_integer = card_art_scale_integer and card_style.texture_margin_left == 12.0 and card_style.texture_margin_top == 12.0
			card_art_scale_integer = card_art_scale_integer and card_style.texture_margin_right == 12.0 and card_style.texture_margin_bottom == 12.0
			_expect(card_art_scale_integer, "Nursery egg art is integer-scaled nearest-neighbor and the approved card uses 12px 9-slice margins")
			var nursery_pixel_layouts: Array[Dictionary] = [
				{"name": "1280x720-160dpi", "viewport": Vector2(1280.0, 720.0), "safe": Rect2(Vector2(24.0, 12.0), Vector2(1232.0, 696.0)), "dpi": 160.0},
				{"name": "1280x720-320dpi", "viewport": Vector2(1280.0, 720.0), "safe": Rect2(Vector2(24.0, 12.0), Vector2(1232.0, 696.0)), "dpi": 320.0},
				{"name": "1280x591-160dpi", "viewport": Vector2(1280.0, 591.0), "safe": Rect2(Vector2.ZERO, Vector2(1280.0, 591.0)), "dpi": 160.0},
				{"name": "1280x591-320dpi", "viewport": Vector2(1280.0, 591.0), "safe": Rect2(Vector2.ZERO, Vector2(1280.0, 591.0)), "dpi": 320.0},
				{"name": "1600x720-160dpi", "viewport": Vector2(1600.0, 720.0), "safe": Rect2(Vector2(24.0, 12.0), Vector2(1552.0, 696.0)), "dpi": 160.0},
				{"name": "1600x720-320dpi", "viewport": Vector2(1600.0, 720.0), "safe": Rect2(Vector2(24.0, 12.0), Vector2(1552.0, 696.0)), "dpi": 320.0},
			]
			var nursery_physical_scales_integer: bool = true
			for pixel_case in nursery_pixel_layouts:
				var pixel_viewport: Vector2 = pixel_case["viewport"]
				var pixel_dpi: float = float(pixel_case["dpi"])
				var pixel_output_scale: Vector2 = Vector2(pixel_dpi / 160.0, pixel_dpi / 160.0)
				var pixel_touch_target: float = 56.0 * pixel_dpi / 160.0
				nursery_ui.call("_layout_ui", pixel_viewport, pixel_case["safe"], pixel_touch_target, pixel_viewport * pixel_output_scale)
				var physical_card_scale_x: float = active_nursery_button.custom_minimum_size.x * pixel_output_scale.x / float(card_style.texture.get_width())
				var physical_card_scale_y: float = active_nursery_button.custom_minimum_size.y * pixel_output_scale.y / float(card_style.texture.get_height())
				var physical_egg_scale_x: float = active_nursery_icon.custom_minimum_size.x * pixel_output_scale.x / float(active_nursery_icon.texture.get_width())
				var physical_egg_scale_y: float = active_nursery_icon.custom_minimum_size.y * pixel_output_scale.y / float(active_nursery_icon.texture.get_height())
				nursery_physical_scales_integer = nursery_physical_scales_integer and is_equal_approx(physical_card_scale_x, roundf(physical_card_scale_x)) and is_equal_approx(physical_card_scale_y, roundf(physical_card_scale_y))
				nursery_physical_scales_integer = nursery_physical_scales_integer and is_equal_approx(physical_egg_scale_x, roundf(physical_egg_scale_x)) and is_equal_approx(physical_egg_scale_y, roundf(physical_egg_scale_y))
				nursery_physical_scales_integer = nursery_physical_scales_integer and active_nursery_button.custom_minimum_size.x >= 256.0 and active_nursery_button.custom_minimum_size.y >= 320.0 and active_nursery_icon.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
			_expect(nursery_physical_scales_integer, "Egg and 9-slice card render at integer physical-pixel scales with nearest sampling across three aspects at 160/320dpi")
			nursery_ui.call("_apply_responsive_layout")
			_expect(str((active_nursery_card.get("progress") as Label).text).contains("0 / 10") and str((active_nursery_card.get("hint") as Label).text).contains("點擊蛋殼"), "Each Nursery card displays its click progress and hatch hint")
			var active_card_rect: Rect2 = active_nursery_button.get_global_rect()
			var progress_rect: Rect2 = (active_nursery_card.get("progress") as Label).get_global_rect()
			var hint_rect: Rect2 = (active_nursery_card.get("hint") as Label).get_global_rect()
			_expect(progress_rect.position.y >= active_card_rect.position.y + 8.0 and hint_rect.position.y >= progress_rect.end.y and hint_rect.end.y <= active_card_rect.end.y - 8.0, "Nursery progress and hint text stay separated and within the 9-slice card bounds")
			active_nursery_button.pressed.emit()
			active_nursery_button.pressed.emit()
			var first_progress: int = int(GameState.get_nursery_egg(active_nursery_egg_id).get("current_clicks", 0))
			var other_progress: int = int(GameState.get_nursery_egg(other_nursery_egg_id).get("current_clicks", 0))
			var active_icon: TextureRect = active_nursery_card.get("icon") as TextureRect
			_expect(first_progress == 2 and other_progress == 0 and GameState.get_active_egg_id() == active_nursery_egg_id and str(active_icon.texture.resource_path).ends_with("egg_crack1_v2_64.png") and str((active_nursery_card.get("progress") as Label).text).contains("2 / 10"), "Nursery advances only the tapped egg, updates its progress, and displays the matching crack frame")
			var nursery_wobble_tweens: Dictionary = nursery_ui.get("wobble_tweens") as Dictionary
			var active_wobble_tween: Tween = nursery_wobble_tweens.get(active_nursery_egg_id) as Tween
			var wobble_frames_valid: bool = is_instance_valid(active_wobble_tween) and active_wobble_tween.is_running()
			for wobble_frame_index in range(3):
				nursery_ui.call("_set_wobble_frame", active_nursery_egg_id, wobble_frame_index)
				var wobble_frame: AtlasTexture = active_icon.texture as AtlasTexture
				wobble_frames_valid = wobble_frames_valid and wobble_frame != null and str(wobble_frame.atlas.resource_path).ends_with("egg_wobble_sheet_v2_3x64.png")
				wobble_frames_valid = wobble_frames_valid and wobble_frame.region == Rect2(float(wobble_frame_index * 64), 0.0, 64.0, 64.0) and wobble_frame.filter_clip
				nursery_ui.call("_render_egg_card", GameState.get_nursery_egg(active_nursery_egg_id))
			_expect(wobble_frames_valid, "Each tap starts a light tween over the approved three-frame wobble sheet")
			_expect(SaveManager.save_game(), "Nursery per-egg progress saves immediately")
			GameState.reset_to_default()
			var nursery_reload_ok: bool = SaveManager.load_game()
			var reloaded_egg: Dictionary = GameState.get_nursery_egg(active_nursery_egg_id)
			_expect(nursery_reload_ok and int(reloaded_egg.get("current_clicks", 0)) == 2 and GameState.get_active_egg_id() == active_nursery_egg_id, "Nursery click count and active egg survive a simulated restart")
			var egg_count_before_name: int = GameState.get_pet_ids().size()
			for _nursery_tap in range(8):
				active_nursery_button.pressed.emit()
			var other_nursery_card: Dictionary = nursery_cards.get(other_nursery_egg_id, {}) as Dictionary
			(other_nursery_card.get("button") as Button).pressed.emit()
			_expect(bool(nursery_ui.get("hatch_locked")) and int(GameState.get_nursery_egg(active_nursery_egg_id).get("current_clicks", 0)) == 10 and int(GameState.get_nursery_egg(other_nursery_egg_id).get("current_clicks", 0)) == 0 and GameState.get_pet_ids().size() == egg_count_before_name, "Tenth Nursery tap locks further egg input without hatching before naming")
			await get_tree().create_timer(0.45).timeout
			var name_overlay: Control = nursery_ui.get_node("NameOverlay") as Control
			var name_edit: LineEdit = nursery_ui.get("name_edit") as LineEdit
			var name_error: Label = nursery_ui.get("name_error_label") as Label
			var name_confirm: Button = nursery_ui.get("name_confirm_button") as Button
			_expect(name_overlay.visible and str((active_nursery_card.get("icon") as TextureRect).texture.resource_path).ends_with("egg_hatch_burst_v2_64.png"), "Nursery plays the burst frame and opens its naming panel")
			await get_tree().create_timer(0.55).timeout
			var nursery_ime_request_seen: bool = false
			var nursery_ime_height_seen: bool = false
			var nursery_ime_events_info_only: bool = true
			for ime_entry in RuntimeLogger.get_logs():
				if ime_entry is Dictionary:
					var ime_message: String = str((ime_entry as Dictionary).get("message", ""))
					if ime_message.contains("IME keyboard") and ime_message.contains("nursery_name"):
						nursery_ime_events_info_only = nursery_ime_events_info_only and str((ime_entry as Dictionary).get("level", "")) == "INFO"
						nursery_ime_request_seen = nursery_ime_request_seen or ime_message.begins_with("IME keyboard request field=nursery_name time_msec=")
						nursery_ime_height_seen = nursery_ime_height_seen or ime_message.begins_with("IME keyboard height field=nursery_name request_msec=") and ime_message.contains(" sample_msec=") and ime_message.contains(" height=")
			if not nursery_ime_request_seen or not nursery_ime_height_seen or not nursery_ime_events_info_only:
				print("G1 nursery IME diagnostic request=%s height=%s info_only=%s logs=%s" % [str(nursery_ime_request_seen), str(nursery_ime_height_seen), str(nursery_ime_events_info_only), RuntimeLogger.get_log_text()])
			_expect(nursery_ime_request_seen and nursery_ime_height_seen and nursery_ime_events_info_only, "Nursery IME request logs its field/time and the 0.5s keyboard-height sample at INFO level")
			name_confirm.pressed.emit()
			_expect(GameState.get_pet_ids().size() == egg_count_before_name and name_error.visible, "Empty Nursery name is rejected without creating a pet")
			name_edit.text = "測試新朋友"
			name_confirm.pressed.emit()
			var named_pet_id: String = GameState.get_selected_pet_id()
			var named_pet: Dictionary = GameState.get_pet(named_pet_id)
			var nursery_saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.get_save_path()))
			var saved_pets: Dictionary = nursery_saved.get("pets", {}) as Dictionary if nursery_saved is Dictionary else {}
			var saved_named_pet: Dictionary = saved_pets.get(named_pet_id, {}) as Dictionary
			var saved_nursery: Dictionary = nursery_saved.get("nursery", {}) as Dictionary if nursery_saved is Dictionary else {}
			var saved_eggs: Array = saved_nursery.get("eggs", []) as Array
			_expect(named_pet.get("nickname") == "測試新朋友" and GameState.get_nursery_egg(active_nursery_egg_id).is_empty() and GameState.get_active_egg_id() == other_nursery_egg_id, "Confirmed Nursery hatch creates the named pet and activates the next egg")
			_expect(saved_named_pet.get("nickname") == "測試新朋友" and saved_eggs.size() == 1 and int((saved_eggs[0] as Dictionary).get("current_clicks", 0)) == 0, "New pet and next-egg progress persist immediately")
			var nursery_timer: Timer = nursery_ui.get("route_timer") as Timer
			if is_instance_valid(nursery_timer):
				nursery_timer.stop()
			GameState.set_data(nursery_snapshot)
			SaveManager.save_game()
			nursery_ui.queue_free()
			await get_tree().process_frame
			aquarium = aquarium_scene.instantiate() as Control
			get_tree().root.add_child(aquarium)
			var transition_food_count: int = GameState.get_food_drops().size()
			aquarium.call("_on_feed_pressed")
			_expect(not bool(aquarium.get("world_actions_enabled")) and GameState.get_food_drops().size() == transition_food_count, "A transition-time touch cannot feed the newly entering Aquarium")
		hatch_ui.queue_free()
		await get_tree().process_frame
	var first_active_pet_id: String = GameState.get_active_pet_ids()[0]
	GameState.set_selected_pet_id(first_active_pet_id)
	for pet_id in GameState.get_active_pet_ids():
		var pet: Dictionary = GameState.get_pet(pet_id)
		pet["hunger"] = 35
		if pet_id == first_active_pet_id:
			pet["nickname"] = "好奇水母喵"
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
	var status_scroll: ScrollContainer = aquarium.get_node("%StatusScroll") as ScrollContainer
	var current_pet_ids: Array[String] = GameState.get_active_pet_ids()
	if not current_pet_ids.is_empty():
		var first_stage_actor: Node = actors.get(current_pet_ids[0]) as Node
		if first_stage_actor != null:
			stage_sprite = first_stage_actor.get_node("%Sprite") as Sprite2D
	_expect(water_background.get_script() == native_tank_script and water_background.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Native DOS tank replaces the soft background and ignores input")
	_expect(water_background.call("get_background_source_rect") == Rect2(4.0, 4.0, 312.0, 172.0) and water_background.call("get_background_content_size") == Vector2(624.0, 344.0), "Native tank draws the unmodified 320x180 source without its four-pixel frame at integer scale")
	_expect(water_background.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Approved integer-scaled ART-DOS-07 aquarium background uses nearest sampling")
	_expect(stage_sprite != null and stage_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Official 64-pixel stage art uses nearest-neighbor sampling")
	_expect(overlay_layer.get_index() > action_layer.get_index() and overlay_layer.mouse_filter == Control.MOUSE_FILTER_IGNORE and modal_input_shield.mouse_filter == Control.MOUSE_FILTER_STOP and overlay_layer.get_index() + 1 == aquarium.get_child_count() and aquarium.get_node("%ShopPanel").get_parent() == overlay_layer and aquarium.get_node("%ShopPanel").get_index() > modal_input_shield.get_index(), "Modal shield and Shop sit above the HUD in input-safe order")
	_expect(not (aquarium.get_node("%RuntimeLogPanel") as Control).visible and (aquarium.get_node("%LogToggleButton") as Button).visible == OS.is_debug_build(), "Runtime log starts hidden and is explicitly available only in debug builds")
	var pet_info_button: Button = aquarium.get("pet_info_button") as Button
	var coin_label: Label = aquarium.get_node("%CoinLabel") as Label
	var inventory_label: Label = aquarium.get_node("%InventoryLabel") as Label
	var pet_details_collapsed: bool = not bool(aquarium.get("pet_info_open")) and pet_info_button != null and pet_info_button.text == "寵物資料"
	pet_details_collapsed = pet_details_collapsed and status_backdrop.visible and coin_label.visible and coin_label.text.begins_with("泡泡幣：")
	pet_details_collapsed = pet_details_collapsed and not (aquarium.get_node("%StageLabel") as Control).visible and inventory_label.visible and inventory_label.text.contains("飼料 ∞")
	_expect(pet_details_collapsed, "Aquarium starts with compact coin and inventory status while individual details stay closed")
	var roster_slots: Array[Button] = aquarium.get("roster_buttons_by_slot") as Array[Button]
	var first_nameplate: Button = roster_slots[0] if not roster_slots.is_empty() else null
	var first_nameplate_label: Label = first_nameplate.get_node_or_null("NameplateLabel") as Label if first_nameplate != null else null
	var first_pet_name: String = str(GameState.get_pet(GameState.get_active_pet_ids()[0]).get("nickname", ""))
	var first_short_id: String = GameState.get_active_pet_ids()[0].trim_prefix("jc_")
	if first_short_id.is_valid_int():
		first_short_id = "%03d" % first_short_id.to_int()
	_expect(roster_slots.size() == 3 and first_nameplate_label != null, "Aquarium creates three fixed pet-nameplate slots")
	_expect(first_nameplate_label != null and first_nameplate_label.text == "%s · %s" % [first_pet_name, first_short_id] and not first_nameplate_label.clip_text and first_nameplate.tooltip_text == first_nameplate_label.text, "Pet nameplate renders the full nickname and ID without clipping")
	var selected_actor_at_start: Node2D = actors.get(GameState.get_active_pet_ids()[0]) as Node2D
	var first_selection_marker: Line2D = selected_actor_at_start.get_node_or_null("SelectedPetIndicator") as Line2D if selected_actor_at_start != null else null
	var selected_body_rect: Rect2 = selected_actor_at_start.call("get_visual_body_rect_global") if selected_actor_at_start != null else Rect2()
	var marker_bounds: Rect2 = _get_line_global_rect(first_selection_marker) if first_selection_marker != null else Rect2()
	var selected_actor_is_top_layer: bool = selected_actor_at_start != null and selected_actor_at_start.z_index == 1
	for pet_id in GameState.get_active_pet_ids():
		var other_actor: Node2D = actors.get(pet_id) as Node2D
		if other_actor != selected_actor_at_start:
			selected_actor_is_top_layer = selected_actor_is_top_layer and other_actor.z_index < selected_actor_at_start.z_index
	_expect(first_selection_marker != null and first_selection_marker.visible and first_selection_marker.z_index < 0 and first_selection_marker.closed and first_selection_marker.width <= 2.0 and first_selection_marker.default_color.a > 0.0 and first_selection_marker.default_color.a < 0.8 and first_selection_marker.global_position.y >= selected_body_rect.end.y + 3.0 and marker_bounds.size.x <= selected_body_rect.size.x * 0.8 and not marker_bounds.intersects(selected_body_rect) and selected_actor_is_top_layer, "Selected pet uses a thin outline below the visible feet, outside the body bounds, and renders above other pets")
	var avoidance_snapshots: Dictionary = {}
	var avoidance_water: Rect2 = aquarium.get("active_water_rect")
	var avoidance_center_local: Vector2 = actor_anchor.to_local(avoidance_water.get_center())
	for pet_id in GameState.get_active_pet_ids():
		var avoidance_actor: Node2D = actors.get(pet_id) as Node2D
		avoidance_snapshots[pet_id] = {
			"position": avoidance_actor.position,
			"roam_target": avoidance_actor.get("roam_target"),
			"behavior_state": str(avoidance_actor.get("behavior_state")),
		}
		avoidance_actor.position = avoidance_center_local
		avoidance_actor.set("roam_target", avoidance_center_local)
		avoidance_actor.set("behavior_state", "idle_roam")
	for _avoidance_frame in range(180):
		aquarium.call("_apply_soft_actor_avoidance", 1.0 / 60.0)
	var idle_overlap_within_limit: bool = true
	var active_actor_ids: Array[String] = GameState.get_active_pet_ids()
	for first_index in range(active_actor_ids.size()):
		for second_index in range(first_index + 1, active_actor_ids.size()):
			var first_actor: Node2D = actors.get(active_actor_ids[first_index]) as Node2D
			var second_actor: Node2D = actors.get(active_actor_ids[second_index]) as Node2D
			idle_overlap_within_limit = idle_overlap_within_limit and _body_overlap_ratio(first_actor, second_actor) <= 0.5
	for pet_id in active_actor_ids:
		var restore_actor: Node2D = actors.get(pet_id) as Node2D
		var restore_state: Dictionary = avoidance_snapshots.get(pet_id, {}) as Dictionary
		restore_actor.position = restore_state.get("position", restore_actor.position)
		restore_actor.set("roam_target", restore_state.get("roam_target", restore_actor.get("roam_target")))
		restore_actor.set("behavior_state", str(restore_state.get("behavior_state", "idle_roam")))
	aquarium.call("_update_selection_markers")
	_expect(idle_overlap_within_limit, "Three overlapping idle pets are softly separated below 50% visible-body overlap within three seconds")
	var chase_inputs_unmodified: bool = true
	for behavior in ["approach_food", "approach_full_food"]:
		for pet_id in active_actor_ids:
			var chase_actor: Node2D = actors.get(pet_id) as Node2D
			chase_actor.position = avoidance_center_local
			chase_actor.set("behavior_state", behavior)
		var chase_positions: Dictionary = {}
		for pet_id in active_actor_ids:
			chase_positions[pet_id] = (actors.get(pet_id) as Node2D).position
		aquarium.call("_apply_soft_actor_avoidance", 1.0 / 60.0)
		for pet_id in active_actor_ids:
			chase_inputs_unmodified = chase_inputs_unmodified and is_equal_approx((actors.get(pet_id) as Node2D).position.distance_to(chase_positions[pet_id]), 0.0)
	for pet_id in active_actor_ids:
		var restore_actor: Node2D = actors.get(pet_id) as Node2D
		var restore_state: Dictionary = avoidance_snapshots.get(pet_id, {}) as Dictionary
		restore_actor.position = restore_state.get("position", restore_actor.position)
		restore_actor.set("roam_target", restore_state.get("roam_target", restore_actor.get("roam_target")))
		restore_actor.set("behavior_state", str(restore_state.get("behavior_state", "idle_roam")))
	aquarium.call("_update_selection_markers")
	_expect(chase_inputs_unmodified, "Food and full-food approaches are not displaced by idle-pet avoidance")
	var food_count_before_daily: int = GameState.get_inventory_count("food_basic")
	var currency_before_daily: int = GameState.get_currency("bubble_coin")
	var daily_claim: Dictionary = GameState.get_daily_claim()
	daily_claim["last_free_food_date"] = "legacy-marker"
	GameState.set_daily_claim(daily_claim)
	var daily_claim_before: Dictionary = GameState.get_daily_claim().duplicate(true)
	(aquarium.get_node("%DailyFoodButton") as Button).pressed.emit()
	_expect(GameState.get_inventory_count("food_basic") == food_count_before_daily, "Unlimited daily-food prompt leaves the legacy quantity unchanged")
	_expect(GameState.get_daily_claim() == daily_claim_before, "Unlimited daily-food prompt does not write a daily claim")
	_expect(GameState.get_currency("bubble_coin") == currency_before_daily, "Unlimited daily-food prompt does not change currency")
	_expect(str((aquarium.get_node("%MessageLabel") as Label).text) == "飼料已無限", "Daily-food prompt shows the approved unlimited-food message")
	var unlimited_shop_panel: Control = aquarium.get_node("%ShopPanel") as Control
	unlimited_shop_panel.call("refresh")
	var food_info_label: Label = unlimited_shop_panel.get_node("%FoodInfoLabel") as Label
	var buy_food_button: Button = unlimited_shop_panel.get_node("%BuyFoodButton") as Button
	var shop_chinese_text: bool = (unlimited_shop_panel.get_node("Main/Header/TitleLabel") as Label).text == "商店"
	shop_chinese_text = shop_chinese_text and (unlimited_shop_panel.get_node("%CloseShopButton") as Button).text == "關閉"
	shop_chinese_text = shop_chinese_text and (unlimited_shop_panel.get_node("%BuyCookieButton") as Button).text == "購買" and (unlimited_shop_panel.get_node("%BuyMedicineButton") as Button).text == "購買"
	shop_chinese_text = shop_chinese_text and (unlimited_shop_panel.get_node("%CookieInfoLabel") as Label).text.begins_with("餅乾") and (unlimited_shop_panel.get_node("%MedicineInfoLabel") as Label).text.begins_with("藥水")
	_expect(shop_chinese_text, "Shop title, close and purchase controls use Traditional Chinese")
	_expect(food_info_label.text.contains("∞") and food_info_label.text.contains("飼料無限") and buy_food_button.disabled, "Shop marks food unlimited and disables its purchase button")
	_expect(not ShopSystem.can_buy("food_basic") and not ShopSystem.buy_item("food_basic"), "Shop transaction cannot buy unlimited food")
	_expect(GameState.get_currency("bubble_coin") == currency_before_daily and GameState.get_inventory_count("food_basic") == food_count_before_daily, "Rejected shop purchase changes neither currency nor legacy quantity")
	var food_cap_tokens: Array[String] = []
	var food_quantity_before_cap: int = GameState.get_inventory_count("food_basic")
	var food_spawn_rects: Array[Rect2] = []
	for _drop_index in range(GameState.MAX_ACTIVE_FOOD_DROPS):
		var spawn_position: Vector2 = aquarium.call("_next_food_spawn_position")
		var cap_drop: Dictionary = aquarium.call("_drop_basic_food", spawn_position)
		var cap_token: String = str(cap_drop.get("token_id", ""))
		if not cap_token.is_empty():
			food_cap_tokens.append(cap_token)
			food_spawn_rects.append(Rect2(spawn_position - Vector2(32.0, 32.0), Vector2(64.0, 64.0)))
	var cap_refused: Dictionary = aquarium.call("_drop_basic_food", Vector2.ZERO)
	var cap_message: String = str((aquarium.get_node("%MessageLabel") as Label).text)
	_expect(food_cap_tokens.size() == 10 and GameState.get_food_drops().size() == 10 and cap_refused.is_empty() and cap_message == "飼料已達上限（10）。", "The first 10 simultaneous drops succeed and the 11th is refused with a Traditional-Chinese limit message")
	var feed_spawn_geometry_valid: bool = food_spawn_rects.size() == GameState.MAX_ACTIVE_FOOD_DROPS
	var spawn_water: Rect2 = aquarium.get("active_water_rect")
	for spawn_index in range(food_spawn_rects.size()):
		var spawn_rect: Rect2 = food_spawn_rects[spawn_index]
		feed_spawn_geometry_valid = feed_spawn_geometry_valid and spawn_rect.position.x >= spawn_water.position.x and spawn_rect.position.y >= spawn_water.position.y
		feed_spawn_geometry_valid = feed_spawn_geometry_valid and spawn_rect.end.x <= spawn_water.end.x and spawn_rect.end.y <= spawn_water.end.y
		for prior_index in range(spawn_index):
			feed_spawn_geometry_valid = feed_spawn_geometry_valid and not spawn_rect.intersects(food_spawn_rects[prior_index])
		for pet_id in GameState.get_active_pet_ids():
			var spawn_actor: Node2D = actors.get(pet_id) as Node2D
			if spawn_actor != null:
				feed_spawn_geometry_valid = feed_spawn_geometry_valid and not spawn_rect.intersects(spawn_actor.call("get_visual_body_rect_global"))
	_expect(feed_spawn_geometry_valid, "Ten visible food markers use separated positions inside the water and avoid all three faces/bodies")
	_expect(GameState.get_inventory_count("food_basic") == food_quantity_before_cap, "Ten accepted drops and the refused 11th leave unlimited legacy inventory unchanged")
	for cap_token in food_cap_tokens:
		GameState.resolve_food_drop(cap_token)
	SaveManager.save_game()
	var cookie_pet_id: String = GameState.get_active_pet_ids()[0]
	var cookie_pet_before: Dictionary = GameState.get_pet(cookie_pet_id)
	var cookie_count_before: int = GameState.get_inventory_count("cookie_basic")
	var cookie_feed_ok: bool = CareSystem.feed_cookie(cookie_pet_id)
	_expect(cookie_feed_ok and GameState.get_inventory_count("cookie_basic") == cookie_count_before - 1, "Cookie feeding still spends one stocked inventory item")
	InventorySystem.add_item("cookie_basic", 1)
	_expect(GameState.get_inventory_count("cookie_basic") == cookie_count_before, "Cookie inventory can be restored through the unchanged add/refund path")
	GameState.set_pet(cookie_pet_id, cookie_pet_before)
	var cookie_actor: Node2D = actors.get(cookie_pet_id) as Node2D
	if cookie_actor != null:
		cookie_actor.call("refresh_pet")
	var world_is_below_hud: bool = aquarium.get_node("%Water").get_index() < actor_anchor.get_index()
	world_is_below_hud = world_is_below_hud and actor_anchor.get_index() < food_container.get_index() and food_container.get_index() < coin_container.get_index()
	world_is_below_hud = world_is_below_hud and coin_container.get_index() < status_backdrop.get_index() and coin_container.get_index() < action_layer.get_index()
	world_is_below_hud = world_is_below_hud and aquarium.mouse_filter == Control.MOUSE_FILTER_IGNORE and (aquarium.get_node("%Water") as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE
	world_is_below_hud = world_is_below_hud and (aquarium.get_node("%FeedButton") as Button).mouse_filter == Control.MOUSE_FILTER_STOP
	_expect(world_is_below_hud, "Aquarium draw order puts HUD above coins, pets, food, and water")
	var primary_action_bar: GridContainer = aquarium.get_node("%ActionBar") as GridContainer
	var primary_buttons_touchable: bool = primary_action_bar.get_child_count() == 4
	var primary_button_texts: Array[String] = ["投食", "摸摸", "沒有蛋了", "更多"]
	for action_node in primary_action_bar.get_children():
		if action_node is Button:
			var action_button: Button = action_node as Button
			primary_buttons_touchable = primary_buttons_touchable and action_button.custom_minimum_size.x >= 48.0 and action_button.custom_minimum_size.y >= 48.0
			var action_index: int = primary_action_bar.get_children().find(action_node)
			if action_index < primary_button_texts.size():
				primary_buttons_touchable = primary_buttons_touchable and action_button.text == primary_button_texts[action_index]
	_expect(primary_buttons_touchable, "Aquarium keeps exactly four primary Traditional-Chinese buttons at 48dp or larger")
	var viewport_16_9: Vector2 = Vector2(1280.0, 720.0)
	var safe_16_9: Rect2 = Rect2(Vector2(24.0, 12.0), Vector2(1232.0, 696.0))
	aquarium.call("_layout_ui", viewport_16_9, safe_16_9)
	var water_16_9: Rect2 = aquarium.get("active_water_rect")
	var nameplate_rect_16_9: Rect2 = Rect2((aquarium.get_node("%PetRosterBackdrop") as Control).position, (aquarium.get_node("%PetRosterBackdrop") as Control).size)
	var details_rect_16_9: Rect2 = Rect2(status_backdrop.position, status_backdrop.size)
	var details_do_not_overlap_nameplates: bool = not nameplate_rect_16_9.intersects(details_rect_16_9) and details_rect_16_9.position.y >= nameplate_rect_16_9.end.y
	aquarium.call("_set_pet_info_open", true)
	details_rect_16_9 = Rect2(status_backdrop.position, status_backdrop.size)
	details_do_not_overlap_nameplates = details_do_not_overlap_nameplates and not nameplate_rect_16_9.intersects(details_rect_16_9) and details_rect_16_9.position.y >= nameplate_rect_16_9.end.y
	_expect(details_do_not_overlap_nameplates, "Pet information panel stays below and does not overlap the top nameplates when expanded")
	aquarium.call("_set_pet_info_open", false)
	aquarium.call("_layout_ui", viewport_16_9, safe_16_9)
	water_16_9 = aquarium.get("active_water_rect")
	var water_inside_safe_16_9: bool = water_16_9.position.x >= safe_16_9.position.x and water_16_9.position.y >= safe_16_9.position.y
	water_inside_safe_16_9 = water_inside_safe_16_9 and water_16_9.end.x <= safe_16_9.end.x and water_16_9.end.y <= safe_16_9.end.y
	var ui_nodes: Array[Control] = [
		status_backdrop,
		status_scroll,
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
	var selected_marker_fits_all_stages: bool = true
	var previous_body_height: float = 0.0
	for stage in range(1, 6):
		visual_probe.call("set_stage", stage, "normal_jellycat")
		aquarium.call("_update_selection_markers")
		var stage_body: Vector2 = visual_probe.call("get_visual_body_size")
		var animated_body: Vector2 = visual_probe.call("get_max_animated_body_size")
		var stage_rect: Rect2 = visual_probe.call("get_visual_body_rect_global")
		var stage_marker: Line2D = visual_probe.get_node_or_null("SelectedPetIndicator") as Line2D
		var stage_marker_rect: Rect2 = _get_line_global_rect(stage_marker) if stage_marker != null else Rect2()
		var stage_fits: bool = stage_rect.position.x >= water_16_9.position.x and stage_rect.position.y >= water_16_9.position.y
		stage_fits = stage_fits and stage_rect.end.x <= water_16_9.end.x and stage_rect.end.y <= water_16_9.end.y
		selected_marker_fits_all_stages = selected_marker_fits_all_stages and stage_marker != null and stage_marker.visible and stage_marker_rect.size.x <= stage_rect.size.x * 0.8 and not stage_marker_rect.intersects(stage_rect)
		stages_grow_within_limit = stages_grow_within_limit and stage_body.y > previous_body_height and animated_body.y <= water_16_9.size.y * 0.25 and stage_fits
		previous_body_height = stage_body.y
	visual_probe.call("set_stage", prior_stage, "normal_jellycat")
	aquarium.call("_update_selection_markers")
	_expect(stages_grow_within_limit, "Five stage textures grow by visible bounds and never exceed 25% with animation")
	_expect(selected_marker_fits_all_stages, "Selected marker stays below each of the five stage textures without covering its visible pixels")
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
	var eating_has_squash_stretch: bool = probe_sprite.scale.x >= probe_base_scale * 0.7 and probe_sprite.scale.x <= probe_base_scale * 1.2
	_expect(eating_has_squash_stretch, "Eat pulse visibly squashes and stretches within safe bounds")
	visual_probe.call("_process", 0.35)
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
	var viewport_19_5_9: Vector2 = Vector2(2340.0, 1080.0)
	var safe_19_5_9: Rect2 = Rect2(Vector2(20.0, 24.0), Vector2(2300.0, 1032.0))
	aquarium.call("_layout_ui", viewport_19_5_9, safe_19_5_9)
	var action_19_5_9: Control = aquarium.get_node("%ActionBar") as Control
	var roster_19_5_9: Control = aquarium.get_node("%PetRoster") as Control
	var action_19_5_9_safe: bool = action_19_5_9.position.x >= safe_19_5_9.position.x and action_19_5_9.position.y >= safe_19_5_9.position.y
	action_19_5_9_safe = action_19_5_9_safe and action_19_5_9.position.x + action_19_5_9.size.x <= safe_19_5_9.end.x and action_19_5_9.position.y + action_19_5_9.size.y <= safe_19_5_9.end.y
	var roster_19_5_9_safe: bool = roster_19_5_9.position.x >= safe_19_5_9.position.x and roster_19_5_9.position.y >= safe_19_5_9.position.y and roster_19_5_9.position.x + roster_19_5_9.size.x <= safe_19_5_9.end.x
	_expect(action_19_5_9_safe and roster_19_5_9_safe, "19.5:9 layout keeps primary actions and pet nameplates inside safe insets")
	var jack_viewport: Vector2 = Vector2(1280.0, 591.0)
	var jack_safe: Rect2 = Rect2(Vector2.ZERO, jack_viewport)
	aquarium.call("_layout_ui", jack_viewport, jack_safe)
	var jack_nameplates: Control = aquarium.get_node("%PetRosterBackdrop") as Control
	var jack_status: Control = aquarium.get_node("%StatusBackdrop") as Control
	var jack_panels_do_not_overlap: bool = not Rect2(jack_nameplates.position, jack_nameplates.size).intersects(Rect2(jack_status.position, jack_status.size))
	aquarium.call("_layout_ui", jack_viewport, jack_safe, 112.0)
	var jack_status_scroll_inside: bool = _control_inside_safe(status_scroll, jack_safe)
	jack_status_scroll_inside = jack_status_scroll_inside and status_scroll.position.x >= jack_status.position.x and status_scroll.position.y >= jack_status.position.y
	jack_status_scroll_inside = jack_status_scroll_inside and status_scroll.position.x + status_scroll.size.x <= jack_status.position.x + jack_status.size.x
	jack_status_scroll_inside = jack_status_scroll_inside and status_scroll.position.y + status_scroll.size.y <= jack_status.position.y + jack_status.size.y
	var jack_320_touch_targets: bool = true
	for roster_button in roster_slots:
		jack_320_touch_targets = jack_320_touch_targets and roster_button.custom_minimum_size.x >= 112.0 and roster_button.custom_minimum_size.y >= 112.0
	for action_node in primary_action_bar.get_children():
		if action_node is Button:
			jack_320_touch_targets = jack_320_touch_targets and (action_node as Button).custom_minimum_size.x >= 112.0 and (action_node as Button).custom_minimum_size.y >= 112.0
	_expect(jack_status_scroll_inside and jack_320_touch_targets, "1280x591 320-dpi layout keeps scrollable status inside its backdrop and every roster/action hit target at least 112px")
	aquarium.call("_set_pet_info_open", true)
	aquarium.call("_layout_ui", jack_viewport, jack_safe, 112.0)
	jack_panels_do_not_overlap = jack_panels_do_not_overlap and not Rect2(jack_nameplates.position, jack_nameplates.size).intersects(Rect2(jack_status.position, jack_status.size)) and jack_status.position.y >= jack_nameplates.position.y + jack_nameplates.size.y
	aquarium.call("_set_pet_info_open", false)
	aquarium.call("_layout_ui", jack_viewport, jack_safe)
	_expect(jack_panels_do_not_overlap, "1280x591 layout separates the top nameplates from the coin/status panel")
	var more_button: Button = aquarium.get_node("%MoreButton") as Button
	var more_panel: PanelContainer = aquarium.get_node("%MorePanel") as PanelContainer
	var more_items: GridContainer = aquarium.get_node("%MoreItems") as GridContainer
	var more_items_scroll: ScrollContainer = more_panel.get_node("MoreContent/MoreItemsScroll") as ScrollContainer
	var feedback_container: Control = aquarium.get_node("%FeedbackContainer") as Control
	more_button.pressed.emit()
	var more_menu_complete: bool = more_panel.visible and more_items.get_child_count() == 7 and more_items_scroll.get_child(0) == more_items
	more_menu_complete = more_menu_complete and more_items.columns == 7
	var more_menu_texts: Array[String] = ["餅乾", "清潔", "藥水", "進化", "商店", "每日飼料", "開啟日誌"]
	for menu_node in more_items.get_children():
		if menu_node is Button:
			var menu_button: Button = menu_node as Button
			var menu_index: int = more_items.get_children().find(menu_node)
			more_menu_complete = more_menu_complete and menu_button.custom_minimum_size.x >= 112.0 and menu_button.custom_minimum_size.y >= 112.0
			if menu_index < more_menu_texts.size():
				more_menu_complete = more_menu_complete and menu_button.text == more_menu_texts[menu_index]
	var more_safe_layouts: Array[Dictionary] = [
		{"name": "1280x720-160dpi", "viewport": viewport_16_9, "safe": safe_16_9, "touch": 56.0},
		{"name": "1280x720-320dpi", "viewport": viewport_16_9, "safe": safe_16_9, "touch": 112.0},
		{"name": "19.5:9", "viewport": viewport_19_5_9, "safe": safe_19_5_9, "touch": 112.0},
		{"name": "20:9", "viewport": Vector2(2400.0, 1080.0), "safe": safe_20_9, "touch": 112.0},
		{"name": "1280x591-160dpi", "viewport": jack_viewport, "safe": jack_safe, "touch": 56.0},
		{"name": "1280x591-320dpi", "viewport": jack_viewport, "safe": jack_safe, "touch": 112.0},
		{"name": "1600x720-160dpi", "viewport": Vector2(1600.0, 720.0), "safe": Rect2(Vector2(24.0, 12.0), Vector2(1552.0, 696.0)), "touch": 56.0},
		{"name": "1600x720-320dpi", "viewport": Vector2(1600.0, 720.0), "safe": Rect2(Vector2(24.0, 12.0), Vector2(1552.0, 696.0)), "touch": 112.0},
	]
	for layout_case in more_safe_layouts:
		var layout_safe: Rect2 = layout_case["safe"]
		var touch_target: float = float(layout_case["touch"])
		var layout_geometry_ok: bool = true
		aquarium.call("_layout_ui", layout_case["viewport"], layout_safe, touch_target)
		await get_tree().process_frame
		layout_geometry_ok = layout_geometry_ok and _control_inside_safe(more_panel, layout_safe)
		layout_geometry_ok = layout_geometry_ok and _control_inside_safe(primary_action_bar, layout_safe)
		layout_geometry_ok = layout_geometry_ok and _control_inside_safe(aquarium.get_node("%PetRoster") as Control, layout_safe)
		layout_geometry_ok = layout_geometry_ok and _control_inside_safe(status_scroll, layout_safe)
		var more_rect: Rect2 = more_panel.get_global_rect()
		var scroll_rect: Rect2 = more_items_scroll.get_global_rect()
		var action_rect: Rect2 = primary_action_bar.get_global_rect()
		layout_geometry_ok = layout_geometry_ok and scroll_rect.size.y >= 112.0 and not more_rect.intersects(action_rect)
		for action_node in primary_action_bar.get_children():
			if action_node is Button:
				var action_button: Button = action_node as Button
				layout_geometry_ok = layout_geometry_ok and action_button.custom_minimum_size.x >= 112.0 and action_button.custom_minimum_size.y >= 112.0
		for menu_node in more_items.get_children():
			if menu_node is Button:
				var menu_button: Button = menu_node as Button
				var button_rect: Rect2 = menu_button.get_global_rect()
				var fully_visible: bool = button_rect.position.x >= scroll_rect.position.x and button_rect.position.y >= scroll_rect.position.y
				fully_visible = fully_visible and button_rect.end.x <= scroll_rect.end.x and button_rect.end.y <= scroll_rect.end.y
				layout_geometry_ok = layout_geometry_ok and menu_button.custom_minimum_size.x >= 112.0 and menu_button.custom_minimum_size.y >= 112.0 and fully_visible
		if not layout_geometry_ok:
			print("G1 More matrix diagnostic case=%s panel=%s scroll=%s action=%s roster=%s targets=%s" % [str(layout_case["name"]), str(more_rect), str(scroll_rect), str(action_rect), str((aquarium.get_node("%PetRoster") as Control).get_global_rect()), str(more_items.get_children().map(func(node: Node) -> Rect2: return (node as Control).get_global_rect()))])
		_expect(layout_geometry_ok, "More layout %s exposes every full-size row inside safe bounds without covering the four keys" % str(layout_case["name"]))
	_expect(more_menu_complete, "More menu contains all seven readable Traditional-Chinese controls in one row")
	var foremost_actor_z: int = actor_anchor.z_index
	for z_actor in actors.values():
		foremost_actor_z = maxi(foremost_actor_z, actor_anchor.z_index + (z_actor as Node2D).z_index)
	_expect(more_panel.z_index > foremost_actor_z and feedback_container.z_index > foremost_actor_z and overlay_layer.z_index > foremost_actor_z, "More, feedback and modal layers render above every pet actor")
	var more_back_food_count: int = GameState.get_food_drops().size()
	var more_back: InputEventKey = InputEventKey.new()
	more_back.pressed = true
	more_back.keycode = KEY_ESCAPE
	aquarium.call("_unhandled_key_input", more_back)
	_expect(not more_panel.visible and GameState.get_food_drops().size() == more_back_food_count, "Back closes More before allowing any water action")
	aquarium.call("_apply_responsive_layout")
	var selected_id: String = GameState.get_active_pet_ids()[0]
	var second_roster_id: String = GameState.get_active_pet_ids()[1]
	GameState.set_selected_pet_id(second_roster_id)
	var selected_roster_slot: Button = roster_slots[0]
	selected_roster_slot.pressed.emit()
	_expect(GameState.get_selected_pet_id() == selected_id and bool(aquarium.get("pet_info_open")), "Tapping a nameplate selects that pet and opens its information/actions")
	print("G1 acceptance: before roster/rename")
	var nickname_edit: LineEdit = aquarium.get_node("%NicknameEdit") as LineEdit
	var rename_button: Button = aquarium.get_node("%RenameButton") as Button
	var rename_panel: PanelContainer = aquarium.get_node("%RenamePanel") as PanelContainer
	var rename_confirm_button: Button = aquarium.get_node("%RenameConfirmButton") as Button
	var rename_cancel_button: Button = aquarium.get_node("%RenameCancelButton") as Button
	_expect(rename_confirm_button.pressed.is_connected(Callable(aquarium, "_on_rename_confirmed")), "Embedded Rename panel is connected to the selected pet")
	var keyboard_requests_before: int = int(aquarium.get("rename_keyboard_request_count"))
	rename_button.pressed.emit()
	await get_tree().process_frame
	var rename_shield_active: bool = modal_input_shield.visible
	var rename_focus_and_keyboard_request: bool = nickname_edit.has_focus() and rename_panel.visible and int(aquarium.get("rename_keyboard_request_count")) == keyboard_requests_before + 1
	_expect(rename_focus_and_keyboard_request, "Rename opens focused with the virtual-keyboard request path exercised")
	await get_tree().create_timer(0.55).timeout
	var rename_ime_request_seen: bool = false
	var rename_ime_height_seen: bool = false
	var rename_ime_events_info_only: bool = true
	for ime_entry in RuntimeLogger.get_logs():
		if ime_entry is Dictionary:
			var ime_message: String = str((ime_entry as Dictionary).get("message", ""))
			if ime_message.contains("IME keyboard") and ime_message.contains("aquarium_rename"):
				rename_ime_events_info_only = rename_ime_events_info_only and str((ime_entry as Dictionary).get("level", "")) == "INFO"
				rename_ime_request_seen = rename_ime_request_seen or ime_message.begins_with("IME keyboard request field=aquarium_rename time_msec=")
				rename_ime_height_seen = rename_ime_height_seen or ime_message.begins_with("IME keyboard height field=aquarium_rename request_msec=") and ime_message.contains(" sample_msec=") and ime_message.contains(" height=")
	_expect(rename_ime_request_seen and rename_ime_height_seen and rename_ime_events_info_only, "Rename IME request logs its field/time and the 0.5s keyboard-height sample at INFO level")
	var food_before_rename_touch: int = GameState.get_food_drops().size()
	var rename_touch: InputEventScreenTouch = InputEventScreenTouch.new()
	var rename_water_rect: Rect2 = aquarium.get("active_water_rect")
	rename_touch.pressed = true
	rename_touch.position = rename_water_rect.get_center()
	aquarium.call("_unhandled_input", rename_touch)
	var rename_blocks_world: bool = GameState.get_food_drops().size() == food_before_rename_touch
	var selected_before_back: String = GameState.get_selected_pet_id()
	var rename_back: InputEventKey = InputEventKey.new()
	rename_back.pressed = true
	rename_back.keycode = KEY_ESCAPE
	aquarium.call("_unhandled_key_input", rename_back)
	_expect(not bool(aquarium.get("rename_modal_active")) and not modal_input_shield.visible and GameState.get_food_drops().size() == food_before_rename_touch and GameState.get_selected_pet_id() == selected_before_back, "Back closes Rename first without leaking a water action or changing pet selection")
	await get_tree().create_timer(0.31).timeout
	keyboard_requests_before = int(aquarium.get("rename_keyboard_request_count"))
	rename_button.pressed.emit()
	await get_tree().process_frame
	_expect(nickname_edit.has_focus() and int(aquarium.get("rename_keyboard_request_count")) == keyboard_requests_before + 1, "Reopening Rename restores focus for Android text entry")
	nickname_edit.text = "Mochi"
	rename_confirm_button.pressed.emit()
	_expect(rename_shield_active and rename_blocks_world and not modal_input_shield.visible and not rename_panel.visible, "Rename modal shields world input and releases it when closed")
	_expect(str(GameState.get_pet(selected_id).get("nickname", "")) == "Mochi", "Rename dialog persists the selected pet nickname")
	var renamed_nickname: String = str(GameState.get_pet(selected_id).get("nickname", ""))
	await get_tree().create_timer(0.31).timeout
	rename_button.pressed.emit()
	await get_tree().process_frame
	nickname_edit.text = "CancelMustNotPersist"
	rename_cancel_button.pressed.emit()
	_expect(not bool(aquarium.get("rename_modal_active")) and str(GameState.get_pet(selected_id).get("nickname", "")) == renamed_nickname, "Cancel closes Rename without changing the selected pet")
	_expect(str((aquarium.get_node("%EvolutionLabel") as Label).text).contains("還需"), "Selected pet UI shows EXP remaining to the next stage in Traditional Chinese")
	var roster_buttons: Dictionary = aquarium.get("roster_buttons_by_id") as Dictionary
	var second_id: String = GameState.get_active_pet_ids()[1]
	var second_pet_button: Button = roster_buttons.get(second_id) as Button
	second_pet_button.pressed.emit()
	_expect(GameState.get_selected_pet_id() == second_id, "Roster selects the pet bound to its explicit ID")
	GameState.set_selected_pet_id(selected_id)
	var nursery_button: Button = aquarium.get_node("%NurseryButton") as Button
	_expect(nursery_button.disabled and GameState.get_nursery_eggs().is_empty() and nursery_button.text == "沒有蛋了", "Nursery disables only after all three starter eggs hatch and reports that no eggs remain")
	_expect(nursery_button.is_connected("pressed", Callable(aquarium, "_on_nursery_pressed")), "Nursery button remains connected to its route handler")
	var roster_backdrop: Control = aquarium.get_node("%PetRosterBackdrop") as Control
	_expect(roster_backdrop.get_theme_stylebox("panel") == null or roster_backdrop.size.x > 0.0, "Roster layout retains a visible flat panel")
	aquarium.call("_apply_responsive_layout")
	await get_tree().create_timer(0.4).timeout
	print("G1 acceptance: after roster/rename paused=%s eggs=%d" % [str(get_tree().paused), GameState.get_nursery_eggs().size()])
	await _run_food_geometry_regression(aquarium, actor_anchor, actors)
	var food_quantity_before_world_feeds: int = GameState.get_inventory_count("food_basic")
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
		_expect(GameState.get_inventory_count("food_basic") == old_inventory, "One unlimited-food drop leaves the legacy quantity unchanged")
	_expect(GameState.get_food_drops().size() == 3 and GameState.get_food_drops().size() < GameState.MAX_ACTIVE_FOOD_DROPS, "Three live feed actions remain below the revised 10-token cap")
	_expect(GameState.get_inventory_count("food_basic") == food_quantity_before_world_feeds, "Three drops preserve the legacy unlimited-food quantity")
	print("G1 acceptance: all drops placed=%d paused=%s" % [GameState.get_food_drops().size(), str(get_tree().paused)])
	var wait_time: float = 0.0
	while not GameState.get_food_drops().is_empty() and wait_time < 25.0:
		await get_tree().create_timer(0.1).timeout
		wait_time += 0.1
	_expect(GameState.get_food_drops().is_empty(), "Three food tokens are consumed once in the real Aquarium scene")
	_expect(GameState.get_inventory_count("food_basic") == food_quantity_before_world_feeds, "Three meals leave the legacy food_basic quantity unchanged")
	var food_pet_diagnostics: Array[String] = []
	for pet_id in GameState.get_active_pet_ids():
		var food_actor: Node2D = actors.get(pet_id) as Node2D
		if food_actor != null:
			food_pet_diagnostics.append("%s:hunger=%d state=%s target=%s pos=%s" % [pet_id, int(GameState.get_pet(pet_id).get("hunger", 0)), str(food_actor.get("behavior_state")), str(food_actor.get("food_drop_id")), str(food_actor.global_position)])
	print("G1 acceptance: food chase wait %.1fs drops=%s claims=%s actors=%s" % [wait_time, str(GameState.get_food_drops()), str(aquarium.get("food_claims")), str(food_pet_diagnostics)])
	for pet_id in GameState.get_active_pet_ids():
		_expect(int(GameState.get_pet(pet_id).get("hunger", 0)) > int(hunger_before_by_pet.get(pet_id, 100)), "%s receives a fair feed" % pet_id)
	await _run_ten_food_drop_cap_restart_cleanup(aquarium)

	_expect(SaveManager.save_game(), "Three-pet Aquarium state saves to the isolated file")
	var food_before_pending_drop: int = GameState.get_inventory_count("food_basic")
	var pending_drop: Dictionary = FoodDropSystem.drop_food(actor_anchor.global_position + Vector2(140.0, 20.0))
	var pending_token: String = str(pending_drop.get("token_id", ""))
	var inventory_with_pending_drop: int = GameState.get_inventory_count("food_basic")
	var one_pet_id: String = GameState.get_active_pet_ids()[0]
	var hunger_before_pending_eat: int = int(GameState.get_pet(one_pet_id).get("hunger", 0))
	_expect(not pending_token.is_empty(), "One more food token is reserved before exit")
	_expect(inventory_with_pending_drop == food_before_pending_drop, "Pending reservation leaves the legacy quantity unchanged")
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
	_expect(GameState.get_inventory_count("food_basic") == inventory_with_pending_drop, "Consumption leaves the legacy quantity unchanged")
	_expect(GameState.get_food_drops().is_empty(), "Consumed token is removed from the save ledger")
	await get_tree().create_timer(0.6).timeout
	print("G1 acceptance: food restart transaction checks done")
	var inventory_before_expiry: int = GameState.get_inventory_count("food_basic")
	var expiry_water: Rect2 = aquarium.get("active_water_rect")
	var expiry_position: Vector2 = expiry_water.position + Vector2(24.0, 24.0)
	aquarium.set_process(false)
	var expiring_drop: Dictionary = GameState.reserve_food_drop("food_basic", expiry_position, Time.get_unix_time_from_system() + 1.0)
	var expiring_token: String = str(expiring_drop.get("token_id", ""))
	_expect(not expiring_token.is_empty() and SaveManager.save_game(), "A short-lived food token saves before expiry")
	_expect(GameState.get_inventory_count("food_basic") == inventory_before_expiry, "Short-lived reservation leaves the legacy quantity unchanged")
	aquarium.call("_update_food_drops", 0.1)
	_expect((aquarium.get("food_drop_visuals") as Dictionary).has(expiring_token), "In-flight food token has a visible sinking marker")
	await get_tree().create_timer(1.2).timeout
	var first_expiry_count: int = FoodDropSystem.expire_due_drops()
	var second_expiry_count: int = FoodDropSystem.expire_due_drops()
	_expect(first_expiry_count == 1 and second_expiry_count == 0, "Expired food token settles once and cannot be removed again")
	aquarium.call("_update_food_drops", 0.1)
	aquarium.set_process(true)
	_expect(GameState.get_food_drops().is_empty(), "An expired food token leaves the ledger")
	_expect(GameState.get_inventory_count("food_basic") == inventory_before_expiry, "Expired cleanup leaves the legacy quantity unchanged")
	_expect(not (aquarium.get("food_drop_visuals") as Dictionary).has(expiring_token), "Expired food marker is removed from the Aquarium")
	_expect(not (aquarium.get("food_claims") as Dictionary).has(expiring_token), "Expired food claim is cleared")
	var inventory_before_duplicate_tap: int = GameState.get_inventory_count("food_basic")
	var active_water: Rect2 = aquarium.get("active_water_rect")
	var water_tap: Vector2 = active_water.position + Vector2(24.0, 24.0)
	var world_touch: InputEventScreenTouch = InputEventScreenTouch.new()
	world_touch.pressed = true
	world_touch.position = water_tap
	var delayed_pair_started_msec: int = Time.get_ticks_msec()
	aquarium.call("_unhandled_input", world_touch)
	var touch_processing_msec: int = Time.get_ticks_msec() - delayed_pair_started_msec
	var delayed_pair_wait_msec: int = maxi(150, 240 - touch_processing_msec)
	OS.delay_usec(delayed_pair_wait_msec * 1000)
	var duplicate_mouse: InputEventMouseButton = InputEventMouseButton.new()
	duplicate_mouse.pressed = true
	duplicate_mouse.button_index = MOUSE_BUTTON_LEFT
	duplicate_mouse.position = water_tap
	aquarium.call("_unhandled_input", duplicate_mouse)
	var delayed_pair_elapsed_msec: int = Time.get_ticks_msec() - delayed_pair_started_msec
	_expect(delayed_pair_elapsed_msec >= 240 and GameState.get_food_drops().size() == 1, "Touch/mouse pair delayed at least 240 ms including synchronous reservation still reserves one token")
	var second_touch: InputEventScreenTouch = InputEventScreenTouch.new()
	second_touch.pressed = true
	second_touch.position = water_tap
	aquarium.call("_unhandled_input", second_touch)
	_expect(GameState.get_food_drops().size() == 2, "A separate second touch at the same location creates another token")
	var second_duplicate_mouse: InputEventMouseButton = InputEventMouseButton.new()
	second_duplicate_mouse.pressed = true
	second_duplicate_mouse.button_index = MOUSE_BUTTON_LEFT
	second_duplicate_mouse.position = water_tap
	aquarium.call("_unhandled_input", second_duplicate_mouse)
	_expect(GameState.get_food_drops().size() == 2, "The second touch also consumes only its paired mouse event")
	var world_mouse_only: InputEventMouseButton = InputEventMouseButton.new()
	world_mouse_only.pressed = true
	world_mouse_only.button_index = MOUSE_BUTTON_LEFT
	world_mouse_only.position = water_tap
	aquarium.call("_unhandled_input", world_mouse_only)
	_expect(GameState.get_food_drops().size() == 3, "A separate mouse-only click at the same location remains usable")
	for paired_drop in GameState.get_food_drops():
		GameState.resolve_food_drop(str(paired_drop.get("token_id", "")))
	SaveManager.save_game()
	aquarium.call("_update_food_drops", 0.0)
	_expect(GameState.get_inventory_count("food_basic") == inventory_before_duplicate_tap, "Paired input and separate drops leave the legacy quantity unchanged")
	await _run_full_food_fairness_case(aquarium, actor_anchor, actors)
	await _run_sunk_food_decay_case(aquarium, actor_anchor, actors)
	await _run_full_ten_food_feedback_case(aquarium, actor_anchor, actors)
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
	var no_modal_back_food_count: int = GameState.get_food_drops().size()
	var no_modal_back_selected: String = GameState.get_selected_pet_id()
	var no_modal_back: InputEventKey = InputEventKey.new()
	no_modal_back.pressed = true
	no_modal_back.keycode = KEY_ESCAPE
	aquarium.call("_unhandled_key_input", no_modal_back)
	_expect(aquarium.is_inside_tree() and GameState.get_food_drops().size() == no_modal_back_food_count and GameState.get_selected_pet_id() == no_modal_back_selected, "Back with no modal leaves the existing Aquarium behavior and game state unchanged")
	var log_was_open: bool = false
	if OS.is_debug_build():
		(aquarium.get_node("%LogToggleButton") as Button).pressed.emit()
		log_was_open = runtime_log_panel.visible
		var log_back_food_count: int = GameState.get_food_drops().size()
		var log_back: InputEventKey = InputEventKey.new()
		log_back.pressed = true
		log_back.keycode = KEY_ESCAPE
		aquarium.call("_unhandled_key_input", log_back)
		_expect(not runtime_log_panel.visible and GameState.get_food_drops().size() == log_back_food_count and aquarium.is_inside_tree(), "Back closes the debug log without leaking an action or leaving the Aquarium")
		var actions_after_log_back: Dictionary = aquarium.get("last_action_time_by_name") as Dictionary
		actions_after_log_back["log_toggle"] = -999999.0
		aquarium.set("last_action_time_by_name", actions_after_log_back)
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
	var shop_back: InputEventKey = InputEventKey.new()
	shop_back.pressed = true
	shop_back.keycode = KEY_ESCAPE
	aquarium.call("_unhandled_key_input", shop_back)
	_expect(not shop_panel.visible and not modal_input_shield.visible and GameState.get_food_drops().size() == modal_food_before and aquarium.is_inside_tree(), "Back closes the topmost Shop without creating food or leaving the Aquarium")
	aquarium.call("_set_shop_open", true)
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
		var idle_art: TextureRect = manual_bubble.get_node("%IdleArt") as TextureRect
		var hint_art: TextureRect = manual_bubble.get_node("%HintArt") as TextureRect
		var pickup_fx_art: TextureRect = manual_bubble.get_node("%PickupFxArt") as TextureRect
		var coin_hitbox_ok: bool = Vector2(manual_bubble.get("custom_minimum_size")).x >= 48.0 and Vector2(manual_bubble.get("custom_minimum_size")).y >= 48.0
		var coin_art_ok: bool = str(manual_bubble.get("text")) == "" and idle_art.size == Vector2(64.0, 64.0) and hint_art.size == Vector2(64.0, 64.0) and pickup_fx_art.size == Vector2(64.0, 64.0)
		coin_art_ok = coin_art_ok and idle_art.texture.resource_path.ends_with("coin_idle_round_v2_32.png")
		coin_art_ok = coin_art_ok and hint_art.texture.resource_path.ends_with("coin_pickup_hint_round_v2_32.png") and pickup_fx_art.texture.resource_path.ends_with("coin_pickup_fx_round_v2_32.png")
		coin_art_ok = coin_art_ok and idle_art.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and hint_art.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and pickup_fx_art.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		var coin_hitbox_transparent: bool = manual_bubble.get_theme_stylebox("normal") is StyleBoxEmpty and manual_bubble.get_theme_stylebox("hover") is StyleBoxEmpty and manual_bubble.get_theme_stylebox("pressed") is StyleBoxEmpty
		_expect(coin_hitbox_ok and coin_art_ok and coin_hitbox_transparent, "Coin keeps a transparent >=48dp hitbox around its larger approved round v2 pixel-art states")
		manual_bubble.button_down.emit()
		_expect(hint_art.visible and not idle_art.visible, "Coin pickup hint art appears on pointer hover")
		manual_bubble.button_up.emit()
		manual_bubble.call("collect", false)
		_expect(pickup_fx_art.visible and not hint_art.visible and not idle_art.visible, "Coin collection shows the approved pickup effect")
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


func _run_ten_food_drop_cap_restart_cleanup(aquarium: Control) -> void:
	var pet_ids: Array[String] = GameState.get_active_pet_ids()
	if pet_ids.size() != 3 or not GameState.get_food_drops().is_empty():
		_expect(false, "Ten-drop regression begins with three pets and an empty food ledger")
		return
	var baseline_pets: Dictionary = {}
	var inventory_before: int = GameState.get_inventory_count("food_basic")
	for pet_id in pet_ids:
		var pet: Dictionary = GameState.get_pet(pet_id)
		baseline_pets[pet_id] = pet.duplicate(true)
		pet["hunger"] = 35
		GameState.set_pet(pet_id, pet)
		var actor: Node2D = (aquarium.get("actors_by_id") as Dictionary).get(pet_id) as Node2D
		if actor != null:
			actor.call("refresh_pet")
	var token_ids: Array[String] = []
	var water: Rect2 = aquarium.get("active_water_rect")
	for drop_index in range(GameState.MAX_ACTIVE_FOOD_DROPS):
		var column: int = drop_index % 5
		var row: int = int(floor(float(drop_index) / 5.0))
		var drop_position: Vector2 = water.position + Vector2(water.size.x * (0.12 + float(column) * 0.18), water.size.y * (0.25 + float(row) * 0.5))
		var drop: Dictionary = FoodDropSystem.drop_food(drop_position)
		var token_id: String = str(drop.get("token_id", ""))
		if not token_id.is_empty():
			token_ids.append(token_id)
	_expect(token_ids.size() == 10 and GameState.get_food_drops().size() == 10, "Ten distinct food tokens can coexist in the durable ledger")
	_expect(GameState.get_inventory_count("food_basic") == inventory_before, "Ten pending tokens leave unlimited legacy inventory unchanged")
	_expect(SaveManager.save_game(), "Ten pending food tokens save before a simulated restart")
	GameState.reset_to_default()
	_expect(SaveManager.load_game(), "Ten-token pending save reloads")
	var reopened_drops: Array[Dictionary] = GameState.get_food_drops()
	var reopened_token_ids: Dictionary = {}
	for drop in reopened_drops:
		var token_id: String = str(drop.get("token_id", ""))
		if not token_id.is_empty():
			reopened_token_ids[token_id] = true
	_expect(reopened_drops.size() == 10 and reopened_token_ids.size() == 10, "Save validation restores all 10 pending food tokens with unique IDs")
	var restored_actors: Dictionary = aquarium.get("actors_by_id") as Dictionary
	for pet_id in pet_ids:
		var actor: Node2D = restored_actors.get(pet_id) as Node2D
		if actor != null:
			actor.call("refresh_pet")
		var actor_wait: float = 0.0
		while actor != null and not bool(actor.call("can_accept_food")) and actor_wait < 3.0:
			await get_tree().create_timer(0.1).timeout
			actor_wait += 0.1
	var processing_started_msec: int = Time.get_ticks_msec()
	aquarium.call("_update_food_drops", 0.0)
	var ten_drop_update_msec: int = Time.get_ticks_msec() - processing_started_msec
	var claims: Dictionary = aquarium.get("food_claims") as Dictionary
	var claim_owners: Dictionary = {}
	var fair_claims: bool = claims.size() == pet_ids.size()
	for raw_token_id in claims.keys():
		var claimant: String = str(claims[raw_token_id])
		fair_claims = fair_claims and reopened_token_ids.has(str(raw_token_id)) and pet_ids.has(claimant) and not claim_owners.has(claimant)
		claim_owners[claimant] = true
	fair_claims = fair_claims and claim_owners.size() == pet_ids.size() and (aquarium.get("food_drop_visuals") as Dictionary).size() == 10
	_expect(fair_claims, "Ten visible pending pellets assign at most one live food claim to each distinct hungry pet")
	print("G1 ten-food batch: pending=10 claims=%d claimants=%d update_ms=%d" % [claims.size(), claim_owners.size(), ten_drop_update_msec])
	if not claims.is_empty():
		var settlement_token: String = str(claims.keys()[0])
		var eater_id: String = str(claims[settlement_token])
		var eater_before: Dictionary = GameState.get_pet(eater_id)
		var hunger_before: int = int(eater_before.get("hunger", 0))
		var exp_before: int = int(eater_before.get("growth_exp", 0))
		var food_exp: int = int(GameApp.get_table("items").get("food_basic", {}).get("growth_exp_add", 0))
		var settled_once: bool = FoodDropSystem.consume_food(settlement_token, eater_id)
		var replay_settled: bool = FoodDropSystem.consume_food(settlement_token, eater_id)
		var eater_after: Dictionary = GameState.get_pet(eater_id)
		_expect(settled_once and not replay_settled and GameState.get_food_drops().size() == 9, "One of 10 restored tokens settles once and its replay is rejected")
		_expect(int(eater_after.get("hunger", 0)) > hunger_before and int(eater_after.get("growth_exp", 0)) == exp_before + food_exp, "Single-token settlement grants exactly one meal benefit")
	else:
		_expect(false, "A restored food token is available for the single-settlement check")
	for drop in GameState.get_food_drops():
		GameState.resolve_food_drop(str(drop.get("token_id", "")))
	aquarium.call("_update_food_drops", 0.0)
	_expect(GameState.get_food_drops().is_empty() and (aquarium.get("food_drop_visuals") as Dictionary).is_empty(), "Consumed and remaining first-batch tokens leave no stale ledger or markers")
	for pet_id in pet_ids:
		var full_pet: Dictionary = GameState.get_pet(pet_id)
		full_pet["hunger"] = 100
		GameState.set_pet(pet_id, full_pet)
		var actor: Node2D = (aquarium.get("actors_by_id") as Dictionary).get(pet_id) as Node2D
		if actor != null:
			actor.call("refresh_pet")
	water = aquarium.get("active_water_rect")
	var sunk_tokens: Array[String] = []
	for drop_index in range(GameState.MAX_ACTIVE_FOOD_DROPS):
		var drop_position: Vector2 = Vector2(
			water.position.x + water.size.x * (0.08 + float(drop_index) * 0.084),
			water.end.y - 32.0
		)
		var drop: Dictionary = FoodDropSystem.drop_food(drop_position)
		var token_id: String = str(drop.get("token_id", ""))
		if not token_id.is_empty():
			sunk_tokens.append(token_id)
	_expect(sunk_tokens.size() == 10 and GameState.get_food_drops().size() == 10, "A second batch of 10 pending tokens is accepted for sink cleanup")
	var hunger_before_sink: Dictionary = {}
	for pet_id in pet_ids:
		hunger_before_sink[pet_id] = GameState.get_pet(pet_id).duplicate(true)
	var sink_update_started_msec: int = Time.get_ticks_msec()
	aquarium.call("_update_food_drops", 60.0)
	var sink_batch_update_msec: int = Time.get_ticks_msec() - sink_update_started_msec
	var cleanup_wait: float = 0.0
	while not GameState.get_food_drops().is_empty() and cleanup_wait < 4.0:
		await get_tree().create_timer(0.1).timeout
		cleanup_wait += 0.1
	var sink_cleanup_ok: bool = GameState.get_food_drops().is_empty()
	sink_cleanup_ok = sink_cleanup_ok and (aquarium.get("food_drop_visuals") as Dictionary).is_empty()
	sink_cleanup_ok = sink_cleanup_ok and (aquarium.get("food_claims") as Dictionary).is_empty()
	for pet_id in pet_ids:
		var pet_before_sink: Dictionary = hunger_before_sink[pet_id]
		var pet_after_sink: Dictionary = GameState.get_pet(pet_id)
		sink_cleanup_ok = sink_cleanup_ok and int(pet_after_sink.get("hunger", -1)) == int(pet_before_sink.get("hunger", -2))
		sink_cleanup_ok = sink_cleanup_ok and int(pet_after_sink.get("growth_exp", -1)) == int(pet_before_sink.get("growth_exp", -2))
	_expect(sink_cleanup_ok, "All 10 sunk tokens clean from the ledger without a hunger or EXP reward")
	_expect(GameState.get_inventory_count("food_basic") == inventory_before, "Ten-token save, settlement and sink cleanup preserve unlimited inventory")
	print("G1 ten-food cleanup: accepted=%d elapsed=%.1fs update_ms=%d" % [sunk_tokens.size(), cleanup_wait, sink_batch_update_msec])
	for pet_id in pet_ids:
		GameState.set_pet(pet_id, baseline_pets[pet_id])
		var actor: Node2D = (aquarium.get("actors_by_id") as Dictionary).get(pet_id) as Node2D
		if actor != null:
			actor.call("refresh_pet")
	SaveManager.save_game()


func _run_full_food_fairness_case(aquarium: Control, actor_anchor: Node2D, actors: Dictionary) -> void:
	var pet_ids: Array[String] = GameState.get_active_pet_ids()
	if pet_ids.size() < 2:
		_expect(false, "Full-food fairness case has a hungry and a full pet")
		return
	var baseline_pets: Dictionary = {}
	for pet_id in pet_ids:
		baseline_pets[pet_id] = GameState.get_pet(pet_id).duplicate(true)
	var hungry_pet_id: String = pet_ids[0]
	var full_pet_id: String = pet_ids[2] if pet_ids.size() > 2 else pet_ids[1]
	var hungry_pet: Dictionary = GameState.get_pet(hungry_pet_id)
	hungry_pet["hunger"] = 35
	GameState.set_pet(hungry_pet_id, hungry_pet)
	var full_pet: Dictionary = GameState.get_pet(full_pet_id)
	full_pet["hunger"] = 100
	GameState.set_pet(full_pet_id, full_pet)
	for pet_id in pet_ids:
		var actor: Node2D = actors.get(pet_id) as Node2D
		if actor != null:
			actor.call("refresh_pet")
	var ready_wait: float = 0.0
	while ready_wait < 3.0:
		var hungry_actor_ready: Node2D = actors.get(hungry_pet_id) as Node2D
		var full_actor_ready: Node2D = actors.get(full_pet_id) as Node2D
		if hungry_actor_ready != null and full_actor_ready != null and bool(hungry_actor_ready.call("can_accept_food")) and bool(full_actor_ready.call("can_react_to_full_food")):
			break
		await get_tree().create_timer(0.1).timeout
		ready_wait += 0.1
	var hungry_actor: Node2D = actors.get(hungry_pet_id) as Node2D
	var full_actor: Node2D = actors.get(full_pet_id) as Node2D
	_expect(hungry_actor != null and full_actor != null and bool(hungry_actor.call("can_accept_food")) and bool(full_actor.call("can_react_to_full_food")), "Hungry and full actors enter their respective feed-ready states")
	if hungry_actor == null or full_actor == null:
		return
	var food_quantity_before: int = GameState.get_inventory_count("food_basic")
	var expected_exp: int = int(GameApp.get_table("items").get("food_basic", {}).get("growth_exp_add", 0))
	var hungry_exp_before: int = int(GameState.get_pet(hungry_pet_id).get("growth_exp", 0))
	var full_exp_before: int = int(GameState.get_pet(full_pet_id).get("growth_exp", 0))
	var water: Rect2 = aquarium.get("active_water_rect")
	var drop: Dictionary = aquarium.call("_drop_basic_food", water.get_center())
	var token_id: String = str(drop.get("token_id", ""))
	_expect(not token_id.is_empty(), "Food with one hungry and one full pet reserves a token")
	if token_id.is_empty():
		return
	aquarium.call("_update_food_drops", 0.0)
	var claims: Dictionary = aquarium.get("food_claims") as Dictionary
	var claim_is_hungry: bool = str(claims.get(token_id, "")) == hungry_pet_id
	var full_reaction_started: bool = str(full_actor.get("full_food_drop_id")) == token_id
	full_reaction_started = full_reaction_started and str(full_actor.get("behavior_state")) in ["approach_full_food", "full_food_refusal"]
	_expect(claim_is_hungry and not claims.values().has(full_pet_id), "Hungry pet claims food while the full pet remains outside the claim ledger")
	_expect(full_reaction_started, "Full pet chases nearby food and starts a non-consuming refusal reaction")
	var marker: Control = (aquarium.get("food_drop_visuals") as Dictionary).get(token_id) as Control
	if marker != null:
		full_actor.position = full_actor.get("roam_target")
		full_actor.call("_process", 0.05)
		hungry_actor.position = actor_anchor.to_local(aquarium.call("_food_marker_center", marker))
		aquarium.call("_update_food_drops", 0.0)
	var has_eating_animation: bool = (aquarium.get("food_eating_visuals") as Dictionary).has(token_id)
	_expect(has_eating_animation, "Food visibly enters the hungry pet's eat animation")
	var wait_time: float = 0.0
	while GameState.get_food_drops().size() > 0 and wait_time < 2.0:
		await get_tree().create_timer(0.1).timeout
		wait_time += 0.1
	var hungry_after: Dictionary = GameState.get_pet(hungry_pet_id)
	var full_after: Dictionary = GameState.get_pet(full_pet_id)
	_expect(GameState.get_food_drops().is_empty(), "Hungry pet settles its token once")
	_expect(int(hungry_after.get("hunger", 0)) == 65 and int(hungry_after.get("growth_exp", 0)) == hungry_exp_before + expected_exp, "Hungry pet receives one meal and its configured EXP")
	_expect(int(full_after.get("hunger", 0)) == 100 and int(full_after.get("growth_exp", 0)) == full_exp_before, "Full pet refusal grants no hunger or growth reward")
	_expect(GameState.get_inventory_count("food_basic") == food_quantity_before, "Hungry meal and full refusal leave the legacy quantity unchanged")
	_expect(str((aquarium.get_node("%MessageLabel") as Label).text).contains("飽足度"), "Eating displays corresponding satiety feedback in Traditional Chinese")
	var food_event_log: String = RuntimeLogger.get_log_text()
	_expect(food_event_log.contains("food eaten %s by %s" % [token_id, hungry_pet_id]), "Successful food consumption logs its token and pet")
	_expect(food_event_log.contains("full refusal %s" % full_pet_id), "Full-pet refusal logs the pet without creating a food claim")
	_expect(food_event_log.contains("hunger 35 -> 65"), "Successful food consumption logs its hunger transition")
	if not GameState.get_food_drops().is_empty():
		_clear_food_regression_token(aquarium, hungry_actor, token_id)
	for pet_id in pet_ids:
		GameState.set_pet(pet_id, baseline_pets[pet_id])
		var actor: Node2D = actors.get(pet_id) as Node2D
		if actor != null:
			actor.call("refresh_pet")
	SaveManager.save_game()


func _run_sunk_food_decay_case(aquarium: Control, actor_anchor: Node2D, actors: Dictionary) -> void:
	var pet_ids: Array[String] = GameState.get_active_pet_ids()
	var baseline_pets: Dictionary = {}
	for pet_id in pet_ids:
		var pet: Dictionary = GameState.get_pet(pet_id)
		baseline_pets[pet_id] = pet.duplicate(true)
		pet["hunger"] = 100
		GameState.set_pet(pet_id, pet)
		var actor: Node2D = actors.get(pet_id) as Node2D
		if actor != null:
			actor.call("refresh_pet")
	var ready_wait: float = 0.0
	while ready_wait < 3.0:
		var all_ready: bool = true
		for pet_id in pet_ids:
			var actor: Node2D = actors.get(pet_id) as Node2D
			all_ready = all_ready and actor != null and bool(actor.call("can_react_to_full_food"))
		if all_ready:
			break
		await get_tree().create_timer(0.1).timeout
		ready_wait += 0.1
	var food_quantity_before: int = GameState.get_inventory_count("food_basic")
	var water: Rect2 = aquarium.get("active_water_rect")
	var floor_position: Vector2 = Vector2(water.get_center().x, water.end.y - 32.0)
	var drop: Dictionary = aquarium.call("_drop_basic_food", floor_position)
	var token_id: String = str(drop.get("token_id", ""))
	_expect(not token_id.is_empty(), "Full pets allow a food token to sink")
	if token_id.is_empty():
		for pet_id in pet_ids:
			GameState.set_pet(pet_id, baseline_pets[pet_id])
		return
	aquarium.call("_update_food_drops", 60.0)
	var visuals: Dictionary = aquarium.get("food_drop_visuals") as Dictionary
	var sunk_visual: Control = visuals.get(token_id) as Control
	var no_hungry_claim: bool = not (aquarium.get("food_claims") as Dictionary).has(token_id)
	_expect(sunk_visual != null and no_hungry_claim, "A sunk pellet remains visual for full pets without occupying a hungry claim")
	var feedback_container: Control = aquarium.get_node("%FeedbackContainer") as Control
	var full_actor: Node2D = actors.get(pet_ids[0]) as Node2D
	var full_pet_state: String = ""
	var refusal_bubble_found: bool = false
	var refusal_bubble: Label = null
	var full_pet_swims_to_food: bool = false
	var original_full_actor_position: Vector2 = Vector2.ZERO
	if full_actor != null and sunk_visual != null:
		var full_food_target: Vector2 = actor_anchor.to_local(aquarium.call("_food_marker_center", sunk_visual))
		original_full_actor_position = full_actor.position
		var approach_target: Vector2 = full_actor.call("_clamp_to_water", full_food_target)
		full_actor.position = full_actor.call("_clamp_to_water", approach_target - Vector2(48.0, 0.0))
		var starting_distance: float = full_actor.position.distance_to(full_food_target)
		for _step in range(120):
			aquarium.call("_update_food_drops", 0.05)
			full_actor.call("_process", 0.05)
			if str(full_actor.get("behavior_state")) == "full_food_refusal":
				break
		full_pet_state = str(full_actor.get("behavior_state"))
		var ending_distance: float = full_actor.position.distance_to(full_food_target)
		full_pet_swims_to_food = starting_distance > 10.0 and ending_distance < starting_distance
		for child in (aquarium.get_node("%FeedbackContainer") as Control).get_children():
			if child is Label and str((child as Label).text) == "吃飽了":
				refusal_bubble_found = true
				refusal_bubble = child as Label
		if not full_pet_swims_to_food or full_pet_state != "full_food_refusal" or not refusal_bubble_found:
			print("G1 full-food refusal diagnostic: token=%s start_distance=%.2f end_distance=%.2f state=%s target=%s reactions=%s bubble=%s" % [token_id, starting_distance, ending_distance, full_pet_state, str(full_actor.get("full_food_drop_id")), str((aquarium.get("full_food_reactions_by_token") as Dictionary).get(token_id, {})), str(refusal_bubble_found)])
	var bubble_readable_over_actor: bool = false
	if refusal_bubble != null and full_actor != null:
		var refusal_rect: Rect2 = refusal_bubble.get_global_rect()
		var refusal_body: Rect2 = full_actor.call("get_visual_body_rect_global")
		var refusal_viewport: Rect2 = aquarium.get_viewport_rect()
		var head_gap: float = refusal_body.position.y - refusal_rect.end.y
		var body_gap: float = refusal_rect.position.y - refusal_body.end.y
		var head_relative: bool = absf(refusal_rect.get_center().x - refusal_body.get_center().x) <= 1.0
		var vertically_clear_of_body: bool = (head_gap >= 0.0 and head_gap <= 48.0) or (body_gap >= 0.0 and body_gap <= 48.0)
		head_relative = head_relative and vertically_clear_of_body
		var within_viewport: bool = _control_inside_safe(refusal_bubble, refusal_viewport)
		bubble_readable_over_actor = head_relative and within_viewport and feedback_container.z_index > actor_anchor.z_index + full_actor.z_index
		if not bubble_readable_over_actor:
			print("G1 refusal-bubble diagnostic body=%s bubble=%s head_relative=%s in_bounds=%s feedback_z=%d anchor_z=%d actor_z=%d" % [str(refusal_body), str(refusal_rect), str(head_relative), str(within_viewport), feedback_container.z_index, actor_anchor.z_index, full_actor.z_index])
	_expect(full_pet_swims_to_food and full_pet_state == "full_food_refusal" and refusal_bubble_found and bubble_readable_over_actor, "Full pet swims to nearby food, keeps its complete 吃飽了 bubble head-relative, in bounds and above actor art")
	if full_actor != null:
		full_actor.position = original_full_actor_position
	await get_tree().create_timer(3.2).timeout
	_expect(not _food_ledger_has_token(token_id) and GameState.get_food_drops().is_empty(), "Sunk unattended food clears from the live ledger after a few seconds")
	_expect(not (aquarium.get("food_drop_visuals") as Dictionary).has(token_id) and not (aquarium.get("food_claims") as Dictionary).has(token_id), "Sunk-token cleanup removes its marker and claim state")
	_expect(RuntimeLogger.get_log_text().contains("food expired/cleared %s" % token_id), "Expired or cleared food logs its token")
	_expect(GameState.get_inventory_count("food_basic") == food_quantity_before, "Sunk-token cleanup does not refund or alter the legacy quantity")
	for pet_id in pet_ids:
		var full_pet_before_restore: Dictionary = GameState.get_pet(pet_id)
		var original_pet: Dictionary = baseline_pets[pet_id] as Dictionary
		_expect(int(full_pet_before_restore.get("hunger", -1)) == 100 and int(full_pet_before_restore.get("growth_exp", -1)) == int(original_pet.get("growth_exp", -2)), "Full-pet refusal grants no hunger or growth reward")
		GameState.set_pet(pet_id, baseline_pets[pet_id])
		var actor: Node2D = actors.get(pet_id) as Node2D
		if actor != null:
			actor.call("refresh_pet")
		_expect(int(GameState.get_pet(pet_id).get("hunger", -1)) == int((baseline_pets[pet_id] as Dictionary).get("hunger", -2)), "Sunk-food regression restores each pet's prior hunger")
	SaveManager.save_game()


func _run_full_ten_food_feedback_case(aquarium: Control, actor_anchor: Node2D, actors: Dictionary) -> void:
	var pet_ids: Array[String] = GameState.get_active_pet_ids()
	_expect(pet_ids.size() == 3 and GameState.get_food_drops().is_empty(), "Ten-token feedback regression starts with three pets and an empty food ledger")
	if pet_ids.size() != 3 or not GameState.get_food_drops().is_empty():
		return
	var baseline_pets: Dictionary = {}
	var actor_states: Dictionary = {}
	var water: Rect2 = aquarium.get("active_water_rect")
	for pet_index in range(pet_ids.size()):
		var pet_id: String = pet_ids[pet_index]
		var pet: Dictionary = GameState.get_pet(pet_id)
		baseline_pets[pet_id] = pet.duplicate(true)
		pet["hunger"] = 100
		GameState.set_pet(pet_id, pet)
		var actor: Node2D = actors.get(pet_id) as Node2D
		if actor == null:
			continue
		actor_states[pet_id] = {
			"position": actor.position,
			"roam_target": actor.get("roam_target"),
			"behavior_state": str(actor.get("behavior_state")),
			"full_food_drop_id": str(actor.get("full_food_drop_id")),
		}
		var actor_point: Vector2 = Vector2(water.position.x + water.size.x * (0.2 + float(pet_index) * 0.3), water.position.y + water.size.y * 0.5)
		actor.position = actor_anchor.to_local(actor_point)
		actor.set("roam_target", actor.position)
		actor.set("behavior_state", "idle_roam")
		actor.set("full_food_drop_id", "")
		actor.call("refresh_pet")

	var food_quantity_before: int = GameState.get_inventory_count("food_basic")
	var growth_before_by_pet: Dictionary = {}
	for pet_id in pet_ids:
		growth_before_by_pet[pet_id] = int(GameState.get_pet(pet_id).get("growth_exp", 0))
	var token_ids: Array[String] = []
	for drop_index in range(GameState.MAX_ACTIVE_FOOD_DROPS):
		var drop_position: Vector2
		if drop_index < pet_ids.size():
			var assigned_actor: Node2D = actors.get(pet_ids[drop_index]) as Node2D
			drop_position = assigned_actor.global_position
		else:
			var x_ratio: float = 0.08 + float(drop_index - pet_ids.size()) * 0.14
			drop_position = Vector2(water.position.x + water.size.x * x_ratio, water.end.y - 40.0)
		var drop: Dictionary = aquarium.call("_drop_basic_food", drop_position)
		var token_id: String = str(drop.get("token_id", ""))
		if not token_id.is_empty():
			token_ids.append(token_id)
	aquarium.call("_update_food_drops", 0.0)
	_expect(token_ids.size() == 10 and GameState.get_food_drops().size() == 10 and (aquarium.get("food_drop_visuals") as Dictionary).size() == 10, "All ten full-pet food tokens and pellet visuals are present before refusal feedback")
	for pet_id in pet_ids:
		var actor: Node2D = actors.get(pet_id) as Node2D
		if actor != null:
			actor.position = actor.get("roam_target")
			actor.call("_process", 0.05)
	var feedback_container: Control = aquarium.get_node("%FeedbackContainer") as Control
	var refusal_bubbles: Array[Label] = []
	for feedback_child in feedback_container.get_children():
		if feedback_child is Label and str((feedback_child as Label).text) == "吃飽了":
			refusal_bubbles.append(feedback_child as Label)
	var readable_bubble_count: int = 0
	var pellets_not_obscured: bool = true
	for bubble in refusal_bubbles:
		var bubble_rect: Rect2 = bubble.get_global_rect()
		var bubble_is_head_relative: bool = false
		for pet_id in pet_ids:
			var actor: Node2D = actors.get(pet_id) as Node2D
			if actor == null:
				continue
			var body_rect: Rect2 = actor.call("get_visual_body_rect_global")
			var top_gap: float = body_rect.position.y - bubble_rect.end.y
			var bottom_gap: float = bubble_rect.position.y - body_rect.end.y
			var x_aligned: bool = absf(bubble_rect.get_center().x - body_rect.get_center().x) <= bubble.size.x + 16.0
			var vertically_clear_of_body: bool = (top_gap >= 0.0 and top_gap <= 48.0) or (bottom_gap >= 0.0 and bottom_gap <= 48.0)
			bubble_is_head_relative = bubble_is_head_relative or x_aligned and vertically_clear_of_body
			pellets_not_obscured = pellets_not_obscured and feedback_container.z_index > actor_anchor.z_index + actor.z_index
		var bubble_in_bounds: bool = _control_inside_safe(bubble, aquarium.get_viewport_rect())
		if bubble_is_head_relative and bubble_in_bounds and bubble.modulate.a >= 0.9:
			readable_bubble_count += 1
	for marker in (aquarium.get("food_drop_visuals") as Dictionary).values():
		for bubble in refusal_bubbles:
			pellets_not_obscured = pellets_not_obscured and not bubble.get_global_rect().intersects((marker as Control).get_global_rect())
	if refusal_bubbles.size() != pet_ids.size() or readable_bubble_count != pet_ids.size() or not pellets_not_obscured:
		print("G1 ten-full-feedback diagnostic bubbles=%d readable=%d pellets_clear=%s positions=%s ledger=%d reactions=%s actors=%s" % [refusal_bubbles.size(), readable_bubble_count, str(pellets_not_obscured), str(refusal_bubbles.map(func(bubble: Label) -> Rect2: return bubble.get_global_rect())), GameState.get_food_drops().size(), str(aquarium.get("full_food_reactions_by_token")), str(pet_ids.map(func(pet_id: String) -> String: return "%s:%s:%s" % [pet_id, str((actors.get(pet_id) as Node2D).get("behavior_state")), str((actors.get(pet_id) as Node2D).get("roam_target"))]))])
	await get_tree().create_timer(0.2).timeout
	var bubbles_stay_visible: bool = refusal_bubbles.size() == pet_ids.size()
	for bubble in refusal_bubbles:
		bubbles_stay_visible = bubbles_stay_visible and bubble.is_visible_in_tree() and bubble.modulate.a >= 0.9 and _control_inside_safe(bubble, aquarium.get_viewport_rect())
	var all_pets_unchanged: bool = true
	for pet_id in pet_ids:
		var pet: Dictionary = GameState.get_pet(pet_id)
		all_pets_unchanged = all_pets_unchanged and int(pet.get("hunger", 0)) == 100 and int(pet.get("growth_exp", 0)) == int(growth_before_by_pet[pet_id])
	_expect(refusal_bubbles.size() == pet_ids.size() and readable_bubble_count == pet_ids.size() and bubbles_stay_visible and pellets_not_obscured and all_pets_unchanged, "After ten full-pet drops, all three head-following refusal labels stay readable above actors and clear of pellets in the 0–3s window with no settlement")
	_expect(GameState.get_food_drops().size() == 10 and GameState.get_inventory_count("food_basic") == food_quantity_before, "Full ten-token refusal leaves the pending ledger and unlimited legacy quantity unchanged")
	for token_id in token_ids:
		GameState.resolve_food_drop(token_id)
	aquarium.call("_update_food_drops", 0.0)
	for bubble in refusal_bubbles:
		bubble.queue_free()
	for pet_id in pet_ids:
		GameState.set_pet(pet_id, baseline_pets[pet_id])
		var actor: Node2D = actors.get(pet_id) as Node2D
		var state: Dictionary = actor_states.get(pet_id, {}) as Dictionary
		if actor != null:
			actor.position = state.get("position", actor.position)
			actor.set("roam_target", state.get("roam_target", actor.get("roam_target")))
			actor.set("behavior_state", str(state.get("behavior_state", "idle_roam")))
			actor.set("full_food_drop_id", str(state.get("full_food_drop_id", "")))
			actor.call("refresh_pet")
	SaveManager.save_game()
	await get_tree().process_frame


func _run_food_geometry_regression(aquarium: Control, actor_anchor: Node2D, actors: Dictionary) -> void:
	var pet_ids: Array[String] = GameState.get_active_pet_ids()
	_expect(pet_ids.size() == 3, "Food geometry regression starts with three active actors")
	_expect(GameState.get_food_drops().is_empty(), "Food geometry regression starts with an empty feed ledger")
	if pet_ids.size() != 3 or not GameState.get_food_drops().is_empty():
		return

	var baseline_pets: Dictionary = {}
	for pet_id in pet_ids:
		baseline_pets[pet_id] = GameState.get_pet(pet_id).duplicate(true)
	var baseline_inventory: int = GameState.get_inventory_count("food_basic")
	var test_case_count: int = 22
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
	_expect(GameState.get_inventory_count("food_basic") == baseline_inventory, "All geometry regression feeds preserve the legacy quantity")
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
	if token_id.is_empty():
		print("G1 food reservation diagnostic: case=%s ledger=%d hunger=%d actor_state=%s can_accept=%s save_blocked=%s has_save=%s" % [label, GameState.get_food_drops().size(), int(GameState.get_pet(pet_id).get("hunger", -1)), str(actor.get("behavior_state")), str(actor.call("can_accept_food")), str(SaveManager.get("load_blocked")), str(SaveManager.has_save())])
	_expect(not token_id.is_empty(), "%s reserves one regression feed" % label)
	if token_id.is_empty():
		GameState.set_pet(pet_id, baseline_pet)
		actor.call("refresh_pet")
		return

	aquarium.call("_update_food_drops", 0.0)
	var visuals: Dictionary = aquarium.get("food_drop_visuals")
	var marker: Control = visuals.get(token_id) as Control
	_expect(marker != null and marker.size == Vector2(64.0, 64.0), "%s renders the approved 64-pixel food pellet" % label)
	_expect(marker is TextureRect and marker.texture.resource_path.ends_with("/food/pellet_32.png"), "%s uses the approved 32-pixel food pellet" % label)
	if marker != null:
		var interaction_rect: Rect2 = aquarium.call("_food_marker_rect", marker)
		_expect(interaction_rect.size == Vector2(32.0, 32.0), "%s keeps the food interaction frame fixed at 32 pixels" % label)
	if marker == null:
		_clear_food_regression_token(aquarium, actor, token_id)
		GameState.set_pet(pet_id, baseline_pet)
		actor.call("refresh_pet")
		return

	var water: Rect2 = aquarium.get("active_water_rect")
	var marker_half: Vector2 = Vector2(32.0, 32.0)
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
	_expect(GameState.get_inventory_count("food_basic") == inventory_before, "%s leaves the legacy food_basic quantity unchanged" % label)
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
	var ready_wait: float = 0.0
	while actor != null and not bool(actor.call("can_accept_food")) and ready_wait < 3.0:
		await get_tree().create_timer(0.1).timeout
		ready_wait += 0.1
	_expect(actor != null and bool(actor.call("can_accept_food")), "Remote-food regression actor becomes ready for the 20:9 feed")
	if actor == null or not bool(actor.call("can_accept_food")):
		GameState.set_pet(pet_id, baseline_pet)
		return
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
	_expect(GameState.get_inventory_count("food_basic") == inventory_before, "The remote regression feed leaves the legacy quantity unchanged")
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
	_expect(GameState.get_inventory_count("food_basic") == inventory_before, "The panel-transition chase leaves the legacy quantity unchanged")
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


func _food_ledger_has_token(token_id: String) -> bool:
	for drop in GameState.get_food_drops():
		if str(drop.get("token_id", "")) == token_id:
			return true
	return false


func _get_line_global_rect(line: Line2D) -> Rect2:
	if line == null or line.points.size() < 2:
		return Rect2()
	var first_point: Vector2 = line.to_global(line.points[0])
	var minimum: Vector2 = first_point
	var maximum: Vector2 = first_point
	for point_index in range(1, line.points.size()):
		var global_point: Vector2 = line.to_global(line.points[point_index])
		minimum.x = minf(minimum.x, global_point.x)
		minimum.y = minf(minimum.y, global_point.y)
		maximum.x = maxf(maximum.x, global_point.x)
		maximum.y = maxf(maximum.y, global_point.y)
	return Rect2(minimum, maximum - minimum).grow(line.width * 0.5)


func _body_overlap_ratio(first_actor: Node2D, second_actor: Node2D) -> float:
	var first_rect: Rect2 = first_actor.call("get_visual_body_rect_global")
	var second_rect: Rect2 = second_actor.call("get_visual_body_rect_global")
	if not first_rect.intersects(second_rect):
		return 0.0
	var minimum_area: float = minf(first_rect.size.x * first_rect.size.y, second_rect.size.x * second_rect.size.y)
	if minimum_area <= 0.0:
		return 0.0
	var overlap_rect: Rect2 = first_rect.intersection(second_rect)
	return overlap_rect.size.x * overlap_rect.size.y / minimum_area


func _control_inside_safe(control: Control, safe_rect: Rect2) -> bool:
	var control_rect: Rect2 = Rect2(control.position, control.size)
	return (
		control_rect.position.x >= safe_rect.position.x
		and control_rect.position.y >= safe_rect.position.y
		and control_rect.end.x <= safe_rect.end.x
		and control_rect.end.y <= safe_rect.end.y
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
