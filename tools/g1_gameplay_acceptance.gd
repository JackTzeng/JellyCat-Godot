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
		var egg_artwork: TextureRect = hatch_ui.get_node("%EggArtwork") as TextureRect
		var hatch_hint: Label = hatch_ui.get_node("%HintLabel") as Label
		_expect(hatch_hint.text.contains("已孵化") and hatch_hint.text.contains("共") and egg_button.is_visible_in_tree() and not egg_button.disabled and egg_button.text.is_empty(), "Hatch entry reports the hatched/total count and keeps a tappable illustrated egg")
		_expect(egg_artwork.texture != null and str(egg_artwork.texture.resource_path).ends_with("egg_idle_v2_64.png") and egg_artwork.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and egg_artwork.size == Vector2(192.0, 192.0), "Hatch artwork uses the approved 64px idle egg at exact 3x nearest scale")
		var hatch_ui_script: Node = hatch_ui
		var hatch_crack_frames: bool = str((hatch_ui_script.call("_get_egg_progress_texture", 0, 10) as Texture2D).resource_path).ends_with("egg_idle_v2_64.png")
		hatch_crack_frames = hatch_crack_frames and str((hatch_ui_script.call("_get_egg_progress_texture", 1, 10) as Texture2D).resource_path).ends_with("egg_crack1_v2_64.png")
		hatch_crack_frames = hatch_crack_frames and str((hatch_ui_script.call("_get_egg_progress_texture", 4, 10) as Texture2D).resource_path).ends_with("egg_crack2_v2_64.png")
		hatch_crack_frames = hatch_crack_frames and str((hatch_ui_script.call("_get_egg_progress_texture", 7, 10) as Texture2D).resource_path).ends_with("egg_crack3_v2_64.png")
		hatch_crack_frames = hatch_crack_frames and str((hatch_ui_script.call("_get_egg_progress_texture", 10, 10) as Texture2D).resource_path).ends_with("egg_hatch_burst_v2_64.png")
		_expect(hatch_crack_frames, "Hatch progress selects the approved idle, crack1–3 and burst egg frames in order")
		for _tap in range(10):
			egg_button.pressed.emit()
		var pet_count_after_hatch: int = GameState.get_pet_ids().size()
		var next_egg_id: String = GameState.get_active_egg_id()
		var next_egg_clicks_before: int = int(GameState.get_nursery_egg(next_egg_id).get("current_clicks", 0))
		egg_button.pressed.emit()
		var next_egg_clicks_after: int = int(GameState.get_nursery_egg(next_egg_id).get("current_clicks", 0))
		_expect(bool(hatch_ui.get("route_pending")) and egg_button.disabled and GameState.get_pet_ids().size() == pet_count_after_hatch and GameState.get_active_egg_id() == next_egg_id and next_egg_clicks_after == next_egg_clicks_before, "A rapid post-hatch tap is blocked before it can advance the next egg")
		_expect(hatch_hint.text == "新的水母喵加入水族箱了！" and str(egg_artwork.texture.resource_path).ends_with("egg_hatch_burst_v2_64.png"), "Hatch completion displays status and the approved burst egg art")
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
			var nursery_pixel_layouts: Array[Dictionary] = [
				{"name": "1280x720-160dpi", "viewport": Vector2(1280.0, 720.0), "safe": Rect2(Vector2(24.0, 12.0), Vector2(1232.0, 696.0)), "dpi": 160.0},
				{"name": "1280x720-320dpi", "viewport": Vector2(1280.0, 720.0), "safe": Rect2(Vector2(24.0, 12.0), Vector2(1232.0, 696.0)), "dpi": 320.0},
				{"name": "1280x591-160dpi", "viewport": Vector2(1280.0, 591.0), "safe": Rect2(Vector2.ZERO, Vector2(1280.0, 591.0)), "dpi": 160.0},
				{"name": "1280x591-320dpi", "viewport": Vector2(1280.0, 591.0), "safe": Rect2(Vector2.ZERO, Vector2(1280.0, 591.0)), "dpi": 320.0},
				{"name": "1600x720-160dpi", "viewport": Vector2(1600.0, 720.0), "safe": Rect2(Vector2(24.0, 12.0), Vector2(1552.0, 696.0)), "dpi": 160.0},
				{"name": "1600x720-320dpi", "viewport": Vector2(1600.0, 720.0), "safe": Rect2(Vector2(24.0, 12.0), Vector2(1552.0, 696.0)), "dpi": 320.0},
			]
			var nursery_fractional_pixel_layouts: Array[Dictionary] = _get_nursery_fractional_pixel_layouts()
			var nursery_all_pixel_layouts: Array[Dictionary] = nursery_pixel_layouts.duplicate()
			nursery_all_pixel_layouts.append_array(nursery_fractional_pixel_layouts)
			var nursery_three_card_matrix: Dictionary = await _test_nursery_three_card_scroll(nursery_ui, GameState.get_nursery_egg(other_nursery_egg_id), nursery_all_pixel_layouts)
			var nursery_third_card_scrollable: bool = bool(nursery_three_card_matrix.get("scrollable", false))
			_expect(nursery_third_card_scrollable, "Nursery three-card overflow remains scrollable to the third card")
			var nursery_all_egg_pixel_checks: int = int(nursery_three_card_matrix.get("geometry_measurements", 0))
			var nursery_all_egg_pixel_geometry_valid: bool = bool(nursery_three_card_matrix.get("geometry_valid", false))
			_expect(nursery_all_egg_pixel_geometry_valid and nursery_all_egg_pixel_checks == nursery_all_pixel_layouts.size() * 6, "All three Nursery cards and eggs stay integer-aligned before and after scrolling in six integer and six expanded-fractional viewport/DPI cases (%d measurements)" % nursery_all_egg_pixel_checks)
			var nursery_fractional_geometry_valid: bool = bool(nursery_three_card_matrix.get("fractional_geometry_valid", false))
			var nursery_fractional_pixel_checks: int = int(nursery_three_card_matrix.get("fractional_geometry_measurements", 0))
			_expect(nursery_fractional_geometry_valid and nursery_fractional_pixel_checks == nursery_fractional_pixel_layouts.size() * 6, "All three Nursery cards and eggs retain exact final physical-pixel edges at true fractional expand scales before/after scroll (%d measurements)" % nursery_fractional_pixel_checks)
			nursery_cards = nursery_ui.get("egg_cards_by_id") as Dictionary
			var active_nursery_card: Dictionary = nursery_cards.get(active_nursery_egg_id, {}) as Dictionary
			var active_nursery_button: Button = active_nursery_card.get("button") as Button
			var active_nursery_icon: TextureRect = active_nursery_card.get("icon") as TextureRect
			var active_nursery_background: TextureRect = active_nursery_card.get("background") as TextureRect
			var card_style: StyleBox = active_nursery_button.get_theme_stylebox("normal")
			var card_art_scale_integer: bool = active_nursery_icon.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
			card_art_scale_integer = card_art_scale_integer and active_nursery_icon.custom_minimum_size == Vector2(128.0, 128.0)
			card_art_scale_integer = card_art_scale_integer and active_nursery_icon.texture.get_size() == Vector2(64.0, 64.0)
			card_art_scale_integer = card_art_scale_integer and active_nursery_background != null
			card_art_scale_integer = card_art_scale_integer and active_nursery_background.texture.resource_path.ends_with("nursery_card_bg_96x112.png")
			card_art_scale_integer = card_art_scale_integer and active_nursery_background.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
			card_art_scale_integer = card_art_scale_integer and active_nursery_background.stretch_mode == TextureRect.STRETCH_SCALE
			card_art_scale_integer = card_art_scale_integer and card_style != null and not (card_style is StyleBoxTexture)
			_expect(card_art_scale_integer, "Nursery egg and card use nearest-scaled full texture regions without 9-slice styling")
			var nursery_physical_scales_integer: bool = true
			var nursery_pixel_case_count: int = 0
			for pixel_case in nursery_pixel_layouts:
				var pixel_viewport: Vector2 = pixel_case["viewport"]
				var pixel_dpi: float = float(pixel_case["dpi"])
				var pixel_output_scale: Vector2 = Vector2(pixel_dpi / 160.0, pixel_dpi / 160.0)
				var pixel_touch_target: float = 56.0 * pixel_dpi / 160.0
				nursery_ui.call("_layout_ui", pixel_viewport, pixel_case["safe"], pixel_touch_target, pixel_viewport * pixel_output_scale)
				for _pixel_layout_frame in range(4):
					await get_tree().process_frame
				var actual_card_rect: Rect2 = active_nursery_button.get_global_rect()
				var actual_background_rect: Rect2 = active_nursery_background.get_global_rect()
				var actual_egg_rect: Rect2 = active_nursery_icon.get_global_rect()
				var card_source_size: Vector2 = active_nursery_background.texture.get_size()
				var egg_source_size: Vector2 = active_nursery_icon.texture.get_size()
				var physical_card_scale: Vector2 = Vector2(
					actual_background_rect.size.x * pixel_output_scale.x / card_source_size.x,
					actual_background_rect.size.y * pixel_output_scale.y / card_source_size.y
				)
				var physical_egg_scale: Vector2 = Vector2(
					actual_egg_rect.size.x * pixel_output_scale.x / egg_source_size.x,
					actual_egg_rect.size.y * pixel_output_scale.y / egg_source_size.y
				)
				var safe_rect: Rect2 = pixel_case["safe"]
				var title_rect: Rect2 = (nursery_ui.get("title_label") as Label).get_global_rect()
				var back_rect: Rect2 = (nursery_ui.get("back_button") as Button).get_global_rect()
				var scroll_rect: Rect2 = egg_scroll.get_global_rect()
				var wrapper_rect: Rect2 = scroll_wrapper.get_global_rect()
				var grid_rect: Rect2 = egg_grid.get_global_rect()
				var header_inside_safe: bool = title_rect.position.x >= safe_rect.position.x and title_rect.position.y >= safe_rect.position.y
				header_inside_safe = header_inside_safe and title_rect.end.x <= safe_rect.end.x and title_rect.end.y <= safe_rect.end.y
				header_inside_safe = header_inside_safe and back_rect.position.x >= safe_rect.position.x and back_rect.position.y >= safe_rect.position.y
				header_inside_safe = header_inside_safe and back_rect.end.x <= safe_rect.end.x and back_rect.end.y <= safe_rect.end.y
				var header_separated: bool = not title_rect.intersects(back_rect) and actual_card_rect.position.y >= maxf(title_rect.end.y, back_rect.end.y)
				var card_within_scroll: bool = actual_card_rect.position.x >= scroll_rect.position.x and actual_card_rect.end.x <= scroll_rect.end.x
				card_within_scroll = card_within_scroll and actual_card_rect.position.y >= scroll_rect.position.y and actual_card_rect.end.y <= scroll_rect.end.y
				var card_geometry_valid: bool = _has_uniform_integer_pixel_scale(actual_background_rect, card_source_size, pixel_output_scale)
				card_geometry_valid = card_geometry_valid and _has_integer_physical_edges(actual_background_rect, pixel_output_scale)
				card_geometry_valid = card_geometry_valid and actual_background_rect.position.is_equal_approx(actual_card_rect.position)
				card_geometry_valid = card_geometry_valid and actual_background_rect.size.is_equal_approx(actual_card_rect.size)
				card_geometry_valid = card_geometry_valid and actual_card_rect.size.x >= 256.0 and actual_card_rect.size.y >= 320.0
				var egg_geometry_valid: bool = _has_uniform_integer_pixel_scale(actual_egg_rect, egg_source_size, pixel_output_scale)
				egg_geometry_valid = egg_geometry_valid and _has_integer_physical_edges(actual_egg_rect, pixel_output_scale)
				var pixel_case_valid: bool = card_geometry_valid and egg_geometry_valid and header_inside_safe and header_separated and card_within_scroll
				nursery_physical_scales_integer = nursery_physical_scales_integer and pixel_case_valid
				if pixel_case_valid:
					nursery_pixel_case_count += 1
					print("G1_NURSERY_PIXEL_CASE %s card_rect=%s card_scale=%s egg_rect=%s egg_scale=%s" % [str(pixel_case["name"]), str(actual_background_rect), str(physical_card_scale), str(actual_egg_rect), str(physical_egg_scale)])
				else:
					print("G1_NURSERY_PIXEL_CASE_FAIL %s card_rect=%s card_scale=%s egg_rect=%s egg_scale=%s scroll_rect=%s wrapper_rect=%s grid_rect=%s header_safe=%s header_separated=%s scroll=%s" % [str(pixel_case["name"]), str(actual_background_rect), str(physical_card_scale), str(actual_egg_rect), str(physical_egg_scale), str(scroll_rect), str(wrapper_rect), str(grid_rect), str(header_inside_safe), str(header_separated), str(card_within_scroll)])
				_expect(pixel_case_valid, "Nursery final card and egg rectangles use equal integer physical-pixel scales and stay in bounds: %s" % str(pixel_case["name"]))
			_expect(nursery_pixel_case_count == nursery_pixel_layouts.size(), "All six nursery pixel configurations pass final-rectangle checks")
			nursery_ui.call("_apply_responsive_layout")
			_expect(str((active_nursery_card.get("progress") as Label).text).contains("0 / 10") and str((active_nursery_card.get("hint") as Label).text).contains("點擊蛋殼"), "Each Nursery card displays its click progress and hatch hint")
			var active_card_rect: Rect2 = active_nursery_button.get_global_rect()
			var progress_rect: Rect2 = (active_nursery_card.get("progress") as Label).get_global_rect()
			var hint_rect: Rect2 = (active_nursery_card.get("hint") as Label).get_global_rect()
			_expect(progress_rect.position.y >= active_card_rect.position.y + 8.0 and hint_rect.position.y >= progress_rect.end.y and hint_rect.end.y <= active_card_rect.end.y - 8.0, "Nursery progress and hint text stay separated and within the card bounds")
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
		pet["hunger"] = int(GameApp.get_balance_value("hungry_hunger_max")) - int(GameApp.get_table("items").get("food_basic", {}).get("hunger_add", 0))
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
	var bottom_hud: Control = aquarium.get_node("%BottomHUD") as Control
	var action_layer: Control = aquarium.get_node("%ActionScroll") as Control
	var water_background: Control = aquarium.get_node("%Water") as Control
	var overlay_layer: Control = aquarium.get_node("%ModalOverlay") as Control
	var modal_input_shield: ColorRect = aquarium.get_node("%ModalInputShield") as ColorRect
	var native_tank_script: Script = load("res://scripts/ui/native_tank.gd") as Script
	var stage_sprite: Sprite2D = null
	var status_scroll: ScrollContainer = aquarium.get_node("%StatusScroll") as ScrollContainer
	var top_panel: VBoxContainer = aquarium.get_node("%TopPanel") as VBoxContainer
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
	var pet_summary_label: Label = aquarium.get_node("%PetSummaryLabel") as Label
	var pet_growth_bar: ProgressBar = aquarium.get_node("%PetGrowthBar") as ProgressBar
	var summary_pet: Dictionary = GameState.get_pet(GameState.get_selected_pet_id())
	var pet_details_collapsed: bool = not bool(aquarium.get("pet_info_open")) and pet_info_button != null and pet_summary_label.text.contains(str(summary_pet.get("nickname", "")))
	pet_details_collapsed = pet_details_collapsed and pet_summary_label.text.contains("飢餓") and pet_summary_label.text.contains("心情") and pet_growth_bar.value >= 0.0
	pet_details_collapsed = pet_details_collapsed and bottom_hud.visible and coin_label.visible and coin_label.text.begins_with("泡泡幣：")
	pet_details_collapsed = pet_details_collapsed and not (aquarium.get_node("%StageLabel") as Control).visible and inventory_label.visible and inventory_label.text.contains("飼料 ∞")
	_expect(pet_details_collapsed, "Aquarium starts with compact coin and inventory status while individual details stay closed")
	var roster_slots: Array[Button] = aquarium.get("roster_buttons_by_slot") as Array[Button]
	var first_nameplate: Button = roster_slots[0] if not roster_slots.is_empty() else null
	var first_nameplate_label: Label = first_nameplate.get_node_or_null("NameplateLabel") as Label if first_nameplate != null else null
	var first_pet_name: String = str(GameState.get_pet(GameState.get_active_pet_ids()[0]).get("nickname", ""))
	var first_slot_number: int = 1
	_expect(roster_slots.size() == 3 and first_nameplate_label != null, "Aquarium creates three fixed pet-nameplate slots")
	_expect(first_nameplate_label != null and first_nameplate_label.text == "%s · 寵物 %d" % [first_pet_name, first_slot_number] and not first_nameplate_label.clip_text and first_nameplate.tooltip_text == first_nameplate_label.text, "Pet nameplate renders the full nickname and visible roster order without clipping")
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
	_expect(aquarium.get_node_or_null("%DailyFoodButton") == null, "Daily-food button is removed from the Aquarium scene")
	_expect(GameState.get_inventory_count("food_basic") == food_count_before_daily, "Removing daily-food UI leaves the legacy quantity unchanged")
	_expect(GameState.get_daily_claim() == daily_claim_before, "Legacy daily-claim data remains readable and unchanged")
	_expect(GameState.get_currency("bubble_coin") == currency_before_daily, "Removing daily-food UI does not change currency")
	var unlimited_shop_panel: Control = aquarium.get_node("%ShopPanel") as Control
	unlimited_shop_panel.call("refresh")
	var food_info_label: Label = unlimited_shop_panel.get_node("%FoodInfoLabel") as Label
	var buy_food_button: Button = unlimited_shop_panel.get_node("%BuyFoodButton") as Button
	var shop_chinese_text: bool = (unlimited_shop_panel.get_node("Main/Header/TitleLabel") as Label).text == "商店"
	shop_chinese_text = shop_chinese_text and (unlimited_shop_panel.get_node("%CloseShopButton") as Button).text == "關閉"
	shop_chinese_text = shop_chinese_text and (unlimited_shop_panel.get_node("%BuyMedicineButton") as Button).text == "購買"
	shop_chinese_text = shop_chinese_text and (unlimited_shop_panel.get_node("%MedicineInfoLabel") as Label).text.begins_with("藥水")
	var cookie_shop_controls_removed: bool = unlimited_shop_panel.get_node_or_null("%BuyCookieButton") == null and unlimited_shop_panel.get_node_or_null("%CookieInfoLabel") == null
	_expect(shop_chinese_text and cookie_shop_controls_removed, "Shop retains its Traditional-Chinese medicine controls while removing the cookie row")
	_expect(food_info_label.text.contains("∞") and food_info_label.text.contains("飼料無限") and buy_food_button.disabled, "Shop marks food unlimited and disables its purchase button")
	_expect(not ShopSystem.can_buy("food_basic") and not ShopSystem.buy_item("food_basic"), "Shop transaction cannot buy unlimited food")
	_expect(GameState.get_currency("bubble_coin") == currency_before_daily and GameState.get_inventory_count("food_basic") == food_count_before_daily, "Rejected shop purchase changes neither currency nor legacy quantity")
	var food_cap_tokens: Array[String] = []
	var food_quantity_before_cap: int = GameState.get_inventory_count("food_basic")
	var food_spawn_rects: Array[Rect2] = []
	for _drop_index in range(GameState.get_max_active_food_drops()):
		var spawn_position: Vector2 = aquarium.call("_next_food_spawn_position")
		var cap_drop: Dictionary = aquarium.call("_drop_basic_food", spawn_position)
		var cap_token: String = str(cap_drop.get("token_id", ""))
		if not cap_token.is_empty():
			food_cap_tokens.append(cap_token)
			food_spawn_rects.append(Rect2(spawn_position - Vector2(32.0, 32.0), Vector2(64.0, 64.0)))
	var cap_refused: Dictionary = aquarium.call("_drop_basic_food", Vector2.ZERO)
	var cap_message: String = str((aquarium.get_node("%MessageLabel") as Label).text)
	var configured_food_limit: int = GameState.get_max_active_food_drops()
	_expect(food_cap_tokens.size() == configured_food_limit and GameState.get_food_drops().size() == configured_food_limit and cap_refused.is_empty() and cap_message == "飼料已達上限（%d）。" % configured_food_limit, "The configured simultaneous-drop limit succeeds and the next drop is refused with a Traditional-Chinese message")
	var feed_spawn_geometry_valid: bool = food_spawn_rects.size() == GameState.get_max_active_food_drops()
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
	_expect(feed_spawn_geometry_valid, "Configured visible food markers use separated positions inside the water and avoid all three faces/bodies")
	_expect(GameState.get_inventory_count("food_basic") == food_quantity_before_cap, "Accepted drops through the configured limit and the refused next drop leave unlimited legacy inventory unchanged")
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
	var cookie_currency_before_shop: int = GameState.get_currency("bubble_coin")
	_expect(not ShopSystem.can_buy("cookie_basic") and not ShopSystem.buy_item("cookie_basic"), "Legacy cookie item is not available for purchase")
	_expect(GameState.get_currency("bubble_coin") == cookie_currency_before_shop and GameState.get_inventory_count("cookie_basic") == cookie_count_before, "Rejecting cookie purchase preserves legacy currency and inventory data")
	GameState.set_pet(cookie_pet_id, cookie_pet_before)
	var cookie_actor: Node2D = actors.get(cookie_pet_id) as Node2D
	if cookie_actor != null:
		cookie_actor.call("refresh_pet")
	var world_is_below_hud: bool = aquarium.get_node("%Water").get_index() < actor_anchor.get_index()
	world_is_below_hud = world_is_below_hud and actor_anchor.get_index() < food_container.get_index() and food_container.get_index() < coin_container.get_index()
	world_is_below_hud = world_is_below_hud and coin_container.get_index() < bottom_hud.get_index() and bottom_hud.get_index() < action_layer.get_index()
	world_is_below_hud = world_is_below_hud and aquarium.mouse_filter == Control.MOUSE_FILTER_IGNORE and (aquarium.get_node("%Water") as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE
	world_is_below_hud = world_is_below_hud and (aquarium.get_node("%FeedButton") as Button).mouse_filter == Control.MOUSE_FILTER_STOP
	_expect(world_is_below_hud, "Aquarium draw order puts HUD above coins, pets, food, and water")
	var primary_action_bar: HBoxContainer = aquarium.get_node("%PrimaryActions") as HBoxContainer
	var primary_buttons_touchable: bool = primary_action_bar.get_child_count() == 4
	var primary_button_texts: Array[String] = ["投食", "摸摸", "育嬰室（%d）" % GameState.get_nursery_eggs().size(), "更多"]
	for action_node in primary_action_bar.get_children():
		if action_node is Button:
			var action_button: Button = action_node as Button
			primary_buttons_touchable = primary_buttons_touchable and action_button.custom_minimum_size.x >= 48.0 and action_button.custom_minimum_size.y >= 48.0
			var action_index: int = primary_action_bar.get_children().find(action_node)
			if action_index < primary_button_texts.size():
				primary_buttons_touchable = primary_buttons_touchable and action_button.text == primary_button_texts[action_index]
	if not primary_buttons_touchable:
		print("G1 primary row diagnostic: count=%d labels=%s minimums=%s" % [
			primary_action_bar.get_child_count(),
			str(primary_action_bar.get_children().map(func(node: Node) -> String: return str((node as Button).text))),
			str(primary_action_bar.get_children().map(func(node: Node) -> Vector2: return (node as Button).custom_minimum_size)),
		])
	_expect(primary_buttons_touchable, "Aquarium keeps exactly four primary Traditional-Chinese buttons at 48dp or larger")
	var viewport_16_9: Vector2 = Vector2(1280.0, 720.0)
	var safe_16_9: Rect2 = Rect2(Vector2(24.0, 12.0), Vector2(1232.0, 696.0))
	aquarium.call("_layout_ui", viewport_16_9, safe_16_9)
	var water_16_9: Rect2 = aquarium.get("active_water_rect")
	var nameplate_rect_16_9: Rect2 = Rect2((aquarium.get_node("%PetRosterBackdrop") as Control).position, (aquarium.get_node("%PetRosterBackdrop") as Control).size)
	var info_expanded_panel: Control = aquarium.get_node("%InfoExpandedPanel") as Control
	var details_rect_16_9: Rect2 = info_expanded_panel.get_global_rect()
	var details_do_not_overlap_nameplates: bool = not nameplate_rect_16_9.intersects(details_rect_16_9) and details_rect_16_9.position.y >= nameplate_rect_16_9.end.y
	aquarium.call("_set_pet_info_open", true)
	details_rect_16_9 = info_expanded_panel.get_global_rect()
	details_do_not_overlap_nameplates = details_do_not_overlap_nameplates and not nameplate_rect_16_9.intersects(details_rect_16_9) and details_rect_16_9.position.y >= nameplate_rect_16_9.end.y
	_expect(details_do_not_overlap_nameplates and details_rect_16_9.end.y <= bottom_hud.position.y, "Pet information expands upward from the bottom HUD without overlapping top nameplates")
	aquarium.call("_set_pet_info_open", false)
	aquarium.call("_layout_ui", viewport_16_9, safe_16_9)
	water_16_9 = aquarium.get("active_water_rect")
	var water_inside_safe_16_9: bool = water_16_9.position.x >= safe_16_9.position.x and water_16_9.position.y >= safe_16_9.position.y
	water_inside_safe_16_9 = water_inside_safe_16_9 and water_16_9.end.x <= safe_16_9.end.x and water_16_9.end.y <= safe_16_9.end.y
	var ui_nodes: Array[Control] = [
		bottom_hud,
		info_expanded_panel,
		aquarium.get_node("%InventoryBackdrop") as Control,
		aquarium.get_node("%PetRosterBackdrop") as Control,
		aquarium.get_node("%MessageLabel") as Control,
		action_layer,
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
		if ui_node.is_visible_in_tree():
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
		if body_rect.position.x < water_16_9.position.x or body_rect.position.y < water_16_9.position.y or body_rect.end.x > water_16_9.end.x or body_rect.end.y > water_16_9.end.y or body_ratio < 0.15 or body_ratio > 0.20:
			print("G1 16:9 actor diagnostic: id=%s body=%s size=%s ratio=%.4f water=%s transition=%s" % [pet_id, str(body_rect), str(body_size), body_ratio, str(water_16_9), str(actor.get("layout_transition_active"))])
	_expect(all_bodies_fit_16_9 and all_stage_one_ratios_fit, "Three stage-one bodies stay visible at 15–20% of 16:9 water height")
	var visual_probe: Node = actors.get(GameState.get_active_pet_ids()[0]) as Node
	var prior_stage: int = int(visual_probe.get("current_stage"))
	var stages_grow_within_limit: bool = true
	var selected_marker_fits_all_stages: bool = true
	var stage_one_body_height: float = 0.0
	var stage_five_body_height: float = 0.0
	for stage in range(1, 6):
		visual_probe.call("set_stage", stage, "normal_jellycat")
		aquarium.call("_update_selection_markers")
		var stage_body: Vector2 = visual_probe.call("get_visual_body_size")
		var stage_rect: Rect2 = visual_probe.call("get_visual_body_rect_global")
		var stage_half_extents: Vector2 = visual_probe.call("_get_conservative_half_extents")
		var animated_body_rect: Rect2 = Rect2(visual_probe.global_position - stage_half_extents, stage_half_extents * 2.0)
		var stage_marker: Line2D = visual_probe.get_node_or_null("SelectedPetIndicator") as Line2D
		var stage_marker_rect: Rect2 = _get_line_global_rect(stage_marker) if stage_marker != null else Rect2()
		var stage_fits: bool = stage_rect.position.x >= water_16_9.position.x and stage_rect.position.y >= water_16_9.position.y
		stage_fits = stage_fits and stage_rect.end.x <= water_16_9.end.x and stage_rect.end.y <= water_16_9.end.y
		selected_marker_fits_all_stages = selected_marker_fits_all_stages and stage_marker != null and stage_marker.visible and stage_marker_rect.size.x <= stage_rect.size.x * 0.8 and not stage_marker_rect.intersects(stage_rect)
		var animated_body_fits: bool = bool(aquarium.call("_rect_fits_inside", animated_body_rect, water_16_9))
		stages_grow_within_limit = stages_grow_within_limit and stage_fits and animated_body_fits
		if stage == 1:
			stage_one_body_height = stage_body.y
		if stage == 5:
			stage_five_body_height = stage_body.y
		if not (stage_fits and animated_body_fits):
			print("G1 stage diagnostic: stage=%d body=%s animated_rect=%s rect=%s water=%s" % [stage, str(stage_body), str(animated_body_rect), str(stage_rect), str(water_16_9)])
	stages_grow_within_limit = stages_grow_within_limit and stage_five_body_height >= stage_one_body_height * 1.35
	visual_probe.call("set_stage", prior_stage, "normal_jellycat")
	aquarium.call("_update_selection_markers")
	_expect(stages_grow_within_limit, "Stage 5 is naturally larger than stage 1 and all five animated bodies remain inside the water")
	_expect(selected_marker_fits_all_stages, "Selected marker stays below each of the five stage textures without covering its visible pixels")
	var stage_scale_cases: Array[Dictionary] = [
		{"name": "16:9", "viewport": viewport_16_9, "safe": safe_16_9},
		{"name": "1280x591", "viewport": Vector2(1280.0, 591.0), "safe": Rect2(Vector2.ZERO, Vector2(1280.0, 591.0))},
		{"name": "20:9", "viewport": Vector2(2400.0, 1080.0), "safe": Rect2(Vector2(40.0, 24.0), Vector2(2320.0, 1032.0))},
	]
	var stage_pixel_scales_valid: bool = true
	for stage_case in stage_scale_cases:
		aquarium.call("_layout_ui", stage_case["viewport"], stage_case["safe"])
		var case_water: Rect2 = aquarium.get("active_water_rect")
		visual_probe.set("layout_transition_active", false)
		visual_probe.call("update_water_bounds_preserving_position", case_water)
		var case_base_scale: float = -1.0
		var case_stage_one_height: float = 0.0
		var case_stage_five_height: float = 0.0
		var case_scales_and_bounds_valid: bool = true
		for stage in range(1, 6):
			visual_probe.call("set_stage", stage, "normal_jellycat")
			var stage_scale: float = float(visual_probe.get("base_scale"))
			var stage_size: Vector2 = visual_probe.call("get_visual_body_size")
			var stage_body_rect: Rect2 = visual_probe.call("get_visual_body_rect_global")
			var stage_half_extents: Vector2 = visual_probe.call("_get_conservative_half_extents")
			var animated_rect: Rect2 = Rect2(visual_probe.global_position - stage_half_extents, stage_half_extents * 2.0)
			if stage == 1:
				case_base_scale = stage_scale
				case_stage_one_height = stage_size.y
			else:
				case_scales_and_bounds_valid = case_scales_and_bounds_valid and is_equal_approx(stage_scale, case_base_scale)
			if stage == 5:
				case_stage_five_height = stage_size.y
			case_scales_and_bounds_valid = case_scales_and_bounds_valid and is_equal_approx(stage_scale, roundf(stage_scale))
			var stage_body_fits: bool = bool(aquarium.call("_rect_fits_inside", stage_body_rect, case_water))
			var stage_animation_fits: bool = animated_rect.position.x >= case_water.position.x - 0.01 and animated_rect.position.y >= case_water.position.y - 0.01
			stage_animation_fits = stage_animation_fits and animated_rect.end.x <= case_water.end.x + 0.01 and animated_rect.end.y <= case_water.end.y + 0.01
			if not stage_body_fits or not stage_animation_fits:
				print("G1 stage pixel bounds diagnostic: case=%s stage=%d multiplier=%.2f body=%s animated=%s water=%s position=%s" % [str(stage_case["name"]), stage, stage_scale, str(stage_body_rect), str(animated_rect), str(case_water), str(visual_probe.global_position)])
			case_scales_and_bounds_valid = case_scales_and_bounds_valid and stage_body_fits and stage_animation_fits
		stage_pixel_scales_valid = stage_pixel_scales_valid and case_scales_and_bounds_valid and case_stage_five_height > case_stage_one_height
		print("G1_STAGE_PIXEL_SCALE_CASE %s scale=%.0f stage1_h=%.1f stage5_h=%.1f safe=%s" % [str(stage_case["name"]), case_base_scale, case_stage_one_height, case_stage_five_height, str(case_scales_and_bounds_valid)])
	aquarium.call("_layout_ui", viewport_16_9, safe_16_9)
	visual_probe.set("layout_transition_active", false)
	visual_probe.call("update_water_bounds_preserving_position", aquarium.get("active_water_rect"))
	visual_probe.call("set_stage", prior_stage, "normal_jellycat")
	aquarium.call("_update_selection_markers")
	_expect(stage_pixel_scales_valid, "Stages 1–5 share one integer pixel multiplier, stage 5 grows, and the full animated body stays inside the water at 16:9, 1280x591, and 20:9")
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
	hud_tap.position = bottom_hud.position + bottom_hud.size / 2.0
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
	var simulated_action: Control = aquarium.get_node("%ActionScroll") as Control
	var simulated_roster: Control = aquarium.get_node("%PetRoster") as Control
	print("G1 layout 20:9 viewport=%s root=%s safe=%s action=%s roster=%s water=%s" % [str(Vector2(2400.0, 1080.0)), str(aquarium.size), str(safe_20_9), str(Rect2(simulated_action.position, simulated_action.size)), str(Rect2(simulated_roster.position, simulated_roster.size)), str(water_20_9)])
	_expect(simulated_action.position.x >= 40.0 and simulated_action.position.y >= 24.0 and simulated_action.position.x + simulated_action.size.x <= 2360.0 and simulated_action.position.y + simulated_action.size.y <= 1056.0, "20:9 layout keeps the action bar inside simulated safe bounds")
	_expect(simulated_roster.position.x >= 40.0 and simulated_roster.position.y >= 24.0 and simulated_roster.position.x + simulated_roster.size.x <= 2360.0, "20:9 layout keeps the pet roster inside simulated safe bounds")
	var viewport_19_5_9: Vector2 = Vector2(2340.0, 1080.0)
	var safe_19_5_9: Rect2 = Rect2(Vector2(20.0, 24.0), Vector2(2300.0, 1032.0))
	aquarium.call("_layout_ui", viewport_19_5_9, safe_19_5_9)
	var action_19_5_9: Control = aquarium.get_node("%ActionScroll") as Control
	var roster_19_5_9: Control = aquarium.get_node("%PetRoster") as Control
	var action_19_5_9_safe: bool = action_19_5_9.position.x >= safe_19_5_9.position.x and action_19_5_9.position.y >= safe_19_5_9.position.y
	action_19_5_9_safe = action_19_5_9_safe and action_19_5_9.position.x + action_19_5_9.size.x <= safe_19_5_9.end.x and action_19_5_9.position.y + action_19_5_9.size.y <= safe_19_5_9.end.y
	var roster_19_5_9_safe: bool = roster_19_5_9.position.x >= safe_19_5_9.position.x and roster_19_5_9.position.y >= safe_19_5_9.position.y and roster_19_5_9.position.x + roster_19_5_9.size.x <= safe_19_5_9.end.x
	_expect(action_19_5_9_safe and roster_19_5_9_safe, "19.5:9 layout keeps primary actions and pet nameplates inside safe insets")
	var jack_viewport: Vector2 = Vector2(1280.0, 591.0)
	var jack_safe: Rect2 = Rect2(Vector2.ZERO, jack_viewport)
	aquarium.call("_layout_ui", jack_viewport, jack_safe)
	var jack_nameplates: Control = aquarium.get_node("%PetRosterBackdrop") as Control
	var jack_status: Control = aquarium.get_node("%InfoExpandedPanel") as Control
	var jack_panels_do_not_overlap: bool = not Rect2(jack_nameplates.position, jack_nameplates.size).intersects(jack_status.get_global_rect())
	var info_matrix_cases: Array[Dictionary] = [
		{"name": "16:9 160dpi", "viewport": viewport_16_9, "safe": safe_16_9, "touch": 56.0},
		{"name": "16:9 320dpi", "viewport": viewport_16_9, "safe": safe_16_9, "touch": 112.0},
		{"name": "1280x591 160dpi", "viewport": jack_viewport, "safe": jack_safe, "touch": 56.0},
		{"name": "1280x591 320dpi", "viewport": jack_viewport, "safe": jack_safe, "touch": 112.0},
		{"name": "20:9 160dpi", "viewport": Vector2(2400.0, 1080.0), "safe": safe_20_9, "touch": 56.0},
		{"name": "20:9 320dpi", "viewport": Vector2(2400.0, 1080.0), "safe": safe_20_9, "touch": 112.0},
	]
	var info_panel_matrix_valid: bool = true
	var info_panel_matrix_checks: int = 0
	aquarium.call("_set_pet_info_open", true)
	for info_case in info_matrix_cases:
		var info_viewport: Vector2 = info_case["viewport"]
		var info_safe: Rect2 = info_case["safe"]
		var info_touch_target: float = float(info_case["touch"])
		aquarium.call("_layout_ui", info_viewport, info_safe, info_touch_target)
		await get_tree().process_frame
		var info_panel_rect: Rect2 = jack_status.get_global_rect()
		var info_content_rect: Rect2 = status_scroll.get_global_rect()
		var info_panel_inside_safe: bool = _control_inside_safe(jack_status, info_safe)
		var info_panel_geometry_valid: bool = info_panel_inside_safe and info_panel_rect.size.y <= info_safe.size.y * 0.45 + 0.1
		var info_panel_width_ratio: float = info_panel_rect.size.x / maxf(info_safe.size.x, 1.0)
		info_panel_geometry_valid = info_panel_geometry_valid and info_panel_width_ratio >= 0.4 and info_panel_width_ratio <= 0.6
		info_panel_geometry_valid = info_panel_geometry_valid and absf(info_panel_rect.end.y - bottom_hud.position.y) <= 0.1
		var no_status_scroll_required: bool = status_scroll.horizontal_scroll_mode == 0 and status_scroll.vertical_scroll_mode == 0
		no_status_scroll_required = no_status_scroll_required and status_scroll.get_h_scroll_bar().max_value <= status_scroll.get_h_scroll_bar().page + 0.1
		no_status_scroll_required = no_status_scroll_required and status_scroll.get_v_scroll_bar().max_value <= status_scroll.get_v_scroll_bar().page + 0.1
		no_status_scroll_required = no_status_scroll_required and top_panel.get_combined_minimum_size().x <= status_scroll.size.x + 1.0
		no_status_scroll_required = no_status_scroll_required and top_panel.get_combined_minimum_size().y <= status_scroll.size.y + 1.0
		var info_content_controls: Array[Control] = [
			aquarium.get_node("%PetNameLabel") as Control,
			aquarium.get_node("%GenderPlaceholderLabel") as Control,
			aquarium.get_node("%StageLabel") as Control,
			aquarium.get_node("%RenameButton") as Control,
			aquarium.get_node("%HungerLabel") as Control,
			aquarium.get_node("%HungerBar") as Control,
			aquarium.get_node("%MoodLabel") as Control,
			aquarium.get_node("%MoodBar") as Control,
			aquarium.get_node("%CleanlinessLabel") as Control,
			aquarium.get_node("%CleanBar") as Control,
			aquarium.get_node("%HealthLabel") as Control,
			aquarium.get_node("%ExpLabel") as Control,
			aquarium.get_node("%GrowthExpBar") as Control,
			aquarium.get_node("%EvolutionLabel") as Control,
			aquarium.get_node("%TouchExpLabel") as Control,
		]
		var all_info_fields_visible_and_unclipped: bool = (aquarium.get_node("%InfoGrid") as GridContainer).columns == 2
		for info_control in info_content_controls:
			var info_control_rect: Rect2 = info_control.get_global_rect()
			var inside_content: bool = info_control_rect.position.x >= info_content_rect.position.x - 0.1 and info_control_rect.position.y >= info_content_rect.position.y - 0.1
			inside_content = inside_content and info_control_rect.end.x <= info_content_rect.end.x + 0.1 and info_control_rect.end.y <= info_content_rect.end.y + 0.1
			all_info_fields_visible_and_unclipped = all_info_fields_visible_and_unclipped and info_control.is_visible_in_tree() and inside_content
			if info_control is Label:
				var info_label: Label = info_control as Label
				all_info_fields_visible_and_unclipped = all_info_fields_visible_and_unclipped and not info_label.clip_text and info_label.autowrap_mode == TextServer.AUTOWRAP_OFF
		var rename_target_ok: bool = (aquarium.get_node("%RenameButton") as Button).custom_minimum_size.x >= maxf(96.0, info_touch_target)
		rename_target_ok = rename_target_ok and (aquarium.get_node("%RenameButton") as Button).custom_minimum_size.y >= info_touch_target
		var bottom_summary_deduplicated: bool = pet_summary_label.text == str(GameState.get_pet(GameState.get_selected_pet_id()).get("nickname", "水母喵")) and not pet_growth_bar.visible
		var info_case_valid: bool = info_panel_geometry_valid and no_status_scroll_required and all_info_fields_visible_and_unclipped and rename_target_ok and bottom_summary_deduplicated
		info_panel_matrix_valid = info_panel_matrix_valid and info_case_valid
		info_panel_matrix_checks += 1
		if not info_case_valid:
			print("G1 info-panel matrix diagnostic: case=%s viewport=%s safe=%s panel=%s content=%s min=%s scrollbars=(%s,%s) fields=%s rename=%s summary=%s" % [str(info_case["name"]), str(info_viewport), str(info_safe), str(info_panel_rect), str(info_content_rect), str(top_panel.get_combined_minimum_size()), str(status_scroll.get_h_scroll_bar().max_value), str(status_scroll.get_v_scroll_bar().max_value), str(all_info_fields_visible_and_unclipped), str(rename_target_ok), str(bottom_summary_deduplicated)])
	_expect(info_panel_matrix_valid and info_panel_matrix_checks == 6, "Info panel shows every two-column field without scrolling or clipping in three aspect ratios × 160/320 dpi, within 45% height and half-width")
	_expect(jack_panels_do_not_overlap, "1280x591 layout separates top nameplates from the upward-expanding detail panel")
	aquarium.call("_set_pet_info_open", false)
	aquarium.call("_layout_ui", jack_viewport, jack_safe)
	var more_button: Button = aquarium.get_node("%MoreButton") as Button
	var more_items: HBoxContainer = aquarium.get_node("%MoreItems") as HBoxContainer
	var more_items_scroll: ScrollContainer = aquarium.get_node("%ActionScroll") as ScrollContainer
	var more_actions_bar: HBoxContainer = aquarium.get_node("%ActionBar") as HBoxContainer
	var primary_actions: HBoxContainer = aquarium.get_node("%PrimaryActions") as HBoxContainer
	var feedback_container: Control = aquarium.get_node("%FeedbackContainer") as Control
	var more_positions_before: Dictionary = {}
	for pet_id in GameState.get_active_pet_ids():
		more_positions_before[pet_id] = (actors.get(pet_id) as Node2D).global_position
	more_button.pressed.emit()
	var more_open_position_stable: bool = true
	for pet_id in GameState.get_active_pet_ids():
		more_open_position_stable = more_open_position_stable and (actors.get(pet_id) as Node2D).global_position.distance_to(more_positions_before[pet_id]) <= 0.01
	var more_menu_complete: bool = bool(aquarium.get("more_actions_open")) and more_items.visible and not primary_actions.visible
	more_menu_complete = more_menu_complete and more_items.get_child_count() == 7 and more_items.get_parent() == more_actions_bar
	more_menu_complete = more_menu_complete and more_items_scroll.get_child(0) == more_actions_bar and more_actions_bar.get_parent() == more_items_scroll
	var more_menu_texts: Array[String] = ["清潔", "藥水", "進化", "商店", "日誌", "測試加速 ×1", "返回"]
	for menu_node in more_items.get_children():
		if menu_node is Button:
			var menu_button: Button = menu_node as Button
			var menu_index: int = more_items.get_children().find(menu_node)
			more_menu_complete = more_menu_complete and menu_button.custom_minimum_size.x >= 112.0 and menu_button.custom_minimum_size.y >= 56.0
			if menu_index < more_menu_texts.size():
				more_menu_complete = more_menu_complete and menu_button.text == more_menu_texts[menu_index]
	var more_safe_layouts: Array[Dictionary] = [
		{"name": "1280x720-160dpi", "viewport": viewport_16_9, "safe": safe_16_9, "touch": 56.0},
		{"name": "1280x720-320dpi", "viewport": viewport_16_9, "safe": safe_16_9, "touch": 112.0},
		{"name": "19.5:9-160dpi", "viewport": viewport_19_5_9, "safe": safe_19_5_9, "touch": 56.0},
		{"name": "19.5:9-320dpi", "viewport": viewport_19_5_9, "safe": safe_19_5_9, "touch": 112.0},
		{"name": "20:9-160dpi", "viewport": Vector2(2400.0, 1080.0), "safe": safe_20_9, "touch": 56.0},
		{"name": "20:9-320dpi", "viewport": Vector2(2400.0, 1080.0), "safe": safe_20_9, "touch": 112.0},
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
		layout_geometry_ok = layout_geometry_ok and _control_inside_safe(more_items_scroll, layout_safe)
		layout_geometry_ok = layout_geometry_ok and more_items_scroll.get_global_rect().size.y >= touch_target
		layout_geometry_ok = layout_geometry_ok and _control_inside_safe(aquarium.get_node("%PetRoster") as Control, layout_safe)
		layout_geometry_ok = layout_geometry_ok and _control_inside_safe(aquarium.get_node("%BottomHUD") as Control, layout_safe)
		var scroll_rect: Rect2 = more_items_scroll.get_global_rect()
		layout_geometry_ok = layout_geometry_ok and more_items.get_global_rect().position.y >= scroll_rect.position.y and more_items.get_global_rect().end.y <= scroll_rect.end.y
		for menu_node in more_items.get_children():
			if menu_node is Button:
				var menu_button: Button = menu_node as Button
				layout_geometry_ok = layout_geometry_ok and menu_button.custom_minimum_size.x >= touch_target and menu_button.custom_minimum_size.y >= touch_target
				var max_scroll: int = maxi(0, int(ceil(more_items.size.x - more_items_scroll.size.x)))
				more_items_scroll.scroll_horizontal = clampi(int(menu_button.position.x), 0, max_scroll)
				await get_tree().process_frame
				var button_rect: Rect2 = menu_button.get_global_rect()
				var fully_visible: bool = button_rect.position.x >= scroll_rect.position.x - 1.0 and button_rect.end.x <= scroll_rect.end.x + 1.0
				fully_visible = fully_visible and button_rect.position.y >= scroll_rect.position.y and button_rect.end.y <= scroll_rect.end.y
				layout_geometry_ok = layout_geometry_ok and fully_visible
		if not layout_geometry_ok:
			print("G1 More matrix diagnostic case=%s scroll=%s menu=%s scroll_min=%s bar=%s bar_min=%s roster=%s targets=%s" % [str(layout_case["name"]), str(scroll_rect), str(more_items.get_global_rect()), str(more_items_scroll.get_combined_minimum_size()), str(more_actions_bar.size), str(more_actions_bar.get_combined_minimum_size()), str((aquarium.get_node("%PetRoster") as Control).get_global_rect()), str(more_items.get_children().map(func(node: Node) -> Rect2: return (node as Control).get_global_rect()))])
		_expect(layout_geometry_ok, "More row %s exposes every full-size control through horizontal scrolling inside safe bounds" % str(layout_case["name"]))
	_expect(more_menu_complete and aquarium.get_node_or_null("%CookieButton") == null, "More keeps its six functions, including test speed, and Back in one bottom row without the removed cookie button")
	_expect(more_open_position_stable, "Opening More does not move or concentrate any pet")
	var foremost_actor_z: int = actor_anchor.z_index
	for z_actor in actors.values():
		foremost_actor_z = maxi(foremost_actor_z, actor_anchor.z_index + (z_actor as Node2D).z_index)
	_expect(more_items_scroll.z_index > foremost_actor_z and feedback_container.z_index > foremost_actor_z and overlay_layer.z_index > foremost_actor_z, "Bottom More row, feedback and modal layers render above every pet actor")
	var more_back_food_count: int = GameState.get_food_drops().size()
	var more_back: InputEventKey = InputEventKey.new()
	more_back.pressed = true
	more_back.keycode = KEY_ESCAPE
	aquarium.call("_unhandled_key_input", more_back)
	_expect(not bool(aquarium.get("more_actions_open")) and primary_actions.visible and not more_items.visible and GameState.get_food_drops().size() == more_back_food_count, "Back returns the same bottom row from More to its four keys without allowing any water action")
	var primary_layout_cases: Array[Dictionary] = [
		{"name": "16:9-160dpi", "viewport": viewport_16_9, "safe": safe_16_9, "touch": 56.0},
		{"name": "16:9-320dpi", "viewport": viewport_16_9, "safe": safe_16_9, "touch": 112.0},
		{"name": "19.5:9-160dpi", "viewport": viewport_19_5_9, "safe": safe_19_5_9, "touch": 56.0},
		{"name": "19.5:9-320dpi", "viewport": viewport_19_5_9, "safe": safe_19_5_9, "touch": 112.0},
		{"name": "20:9-160dpi", "viewport": Vector2(2400.0, 1080.0), "safe": safe_20_9, "touch": 56.0},
		{"name": "20:9-320dpi", "viewport": Vector2(2400.0, 1080.0), "safe": safe_20_9, "touch": 112.0},
	]
	for primary_case in primary_layout_cases:
		aquarium.call("_layout_ui", primary_case["viewport"], primary_case["safe"], float(primary_case["touch"]))
		await get_tree().process_frame
		var primary_scroll_rect: Rect2 = more_items_scroll.get_global_rect()
		var primary_safe: Rect2 = primary_case["safe"]
		var primary_layout_valid: bool = primary_actions.visible and _control_inside_safe(more_items_scroll, primary_safe)
		for primary_node in primary_actions.get_children():
			if primary_node is Button:
				var primary_button: Button = primary_node as Button
				var primary_button_rect: Rect2 = primary_button.get_global_rect()
				primary_layout_valid = primary_layout_valid and primary_button.custom_minimum_size.x >= float(primary_case["touch"]) and primary_button.custom_minimum_size.y >= float(primary_case["touch"])
				primary_layout_valid = primary_layout_valid and primary_button_rect.position.x >= primary_scroll_rect.position.x and primary_button_rect.position.y >= primary_scroll_rect.position.y
				primary_layout_valid = primary_layout_valid and primary_button_rect.end.x <= primary_scroll_rect.end.x and primary_button_rect.end.y <= primary_scroll_rect.end.y
				primary_layout_valid = primary_layout_valid and primary_button_rect.position.x >= primary_safe.position.x and primary_button_rect.position.y >= primary_safe.position.y
				primary_layout_valid = primary_layout_valid and primary_button_rect.end.x <= primary_safe.end.x and primary_button_rect.end.y <= primary_safe.end.y
		if not primary_layout_valid:
			print("G1 primary matrix diagnostic case=%s scroll=%s safe=%s scroll_min=%s buttons=%s" % [str(primary_case["name"]), str(primary_scroll_rect), str(primary_safe), str(more_items_scroll.get_combined_minimum_size()), str(primary_actions.get_children().map(func(node: Node) -> Rect2: return (node as Control).get_global_rect()))])
		_expect(primary_layout_valid and primary_actions.get_child_count() == 4, "Primary bottom-row buttons stay fully visible and touch-sized at %s" % str(primary_case["name"]))
	var toggle_actor_snapshots: Dictionary = {}
	var live_viewport_size: Vector2 = aquarium.get_viewport_rect().size
	aquarium.set("pet_info_open", true)
	aquarium.call("_layout_ui", live_viewport_size, aquarium.call("_get_safe_viewport_rect", live_viewport_size))
	var open_toggle_water: Rect2 = aquarium.get("active_water_rect")
	var toggle_pet_ids: Array[String] = GameState.get_active_pet_ids()
	for toggle_index in range(toggle_pet_ids.size()):
		var pet_id: String = toggle_pet_ids[toggle_index]
		var toggle_actor: Node2D = actors.get(pet_id) as Node2D
		toggle_actor_snapshots[pet_id] = {"position": toggle_actor.position, "roam_target": toggle_actor.get("roam_target")}
		var distributed_position: Vector2 = Vector2(
			open_toggle_water.get_center().x + (float(toggle_index) - float(toggle_pet_ids.size() - 1) * 0.5) * open_toggle_water.size.x * 0.32,
			open_toggle_water.get_center().y
		)
		toggle_actor.position = actor_anchor.to_local(distributed_position)
		toggle_actor.set("roam_target", toggle_actor.position)
		aquarium.call("_update_selection_markers")
	aquarium.set("pet_info_open", false)
	aquarium.call("_apply_responsive_layout")
	var immediate_panel_positions_stable: bool = more_open_position_stable
	var panel_targets_stable: bool = true
	var toggle_panel_layout_clear: bool = true
	var panel_toggle_position_log: Array[String] = []
	for _panel_toggle in range(10):
		for should_open_info in [true, false]:
			var before_positions: Dictionary = {}
			var before_targets: Dictionary = {}
			for pet_id in GameState.get_active_pet_ids():
				var info_actor: Node2D = actors.get(pet_id) as Node2D
				before_positions[pet_id] = info_actor.global_position
				before_targets[pet_id] = info_actor.get("roam_target")
			aquarium.call("_set_pet_info_open", should_open_info)
			for pet_id in GameState.get_active_pet_ids():
				var info_actor: Node2D = actors.get(pet_id) as Node2D
				var movement: float = info_actor.global_position.distance_to(before_positions[pet_id])
				immediate_panel_positions_stable = immediate_panel_positions_stable and movement <= 0.01
				panel_targets_stable = panel_targets_stable and info_actor.get("roam_target") == before_targets[pet_id]
				panel_toggle_position_log.append("info-%s:%s=%s" % [str(should_open_info), pet_id, str(info_actor.global_position)])
			var toggle_panel_rect: Rect2 = info_expanded_panel.get_global_rect()
			var toggle_water_rect: Rect2 = aquarium.get("active_water_rect")
			if should_open_info:
				toggle_panel_layout_clear = toggle_panel_layout_clear and info_expanded_panel.visible and not toggle_panel_rect.intersects((aquarium.get_node("%PetRosterBackdrop") as Control).get_global_rect())
				toggle_panel_layout_clear = toggle_panel_layout_clear and not toggle_panel_rect.intersects((aquarium.get_node("%InventoryBackdrop") as Control).get_global_rect()) and toggle_panel_rect.end.y <= bottom_hud.position.y
				for pet_id in GameState.get_active_pet_ids():
					var toggle_actor: Node2D = actors.get(pet_id) as Node2D
					var toggle_actor_rect: Rect2 = toggle_actor.call("get_visual_body_rect_global")
					toggle_panel_layout_clear = toggle_panel_layout_clear and toggle_actor_rect.position.y >= toggle_water_rect.position.y and toggle_actor_rect.end.y <= toggle_water_rect.end.y
					toggle_panel_layout_clear = toggle_panel_layout_clear and bool(toggle_actor.call("is_panel_evasion_active")) == toggle_actor_rect.intersects(toggle_panel_rect)
			else:
				toggle_panel_layout_clear = toggle_panel_layout_clear and not info_expanded_panel.visible
				for pet_id in GameState.get_active_pet_ids():
					toggle_panel_layout_clear = toggle_panel_layout_clear and not bool((actors.get(pet_id) as Node2D).call("is_panel_evasion_active"))
	_expect(immediate_panel_positions_stable and panel_targets_stable and toggle_panel_layout_clear and panel_toggle_position_log.size() == 60, "Ten info expand/collapse cycles preserve pet positions and swim targets while keeping details, top labels, and pets unobscured")
	for panel_position in panel_toggle_position_log:
		print("G1 info toggle position: %s" % panel_position)
	var more_targets_stable: bool = true
	var more_toggle_position_log: Array[String] = []
	var more_spread_before: float = 0.0
	var pet_ids_for_more: Array[String] = GameState.get_active_pet_ids()
	for first_index in range(pet_ids_for_more.size()):
		for second_index in range(first_index + 1, pet_ids_for_more.size()):
			var first_more_actor: Node2D = actors.get(pet_ids_for_more[first_index]) as Node2D
			var second_more_actor: Node2D = actors.get(pet_ids_for_more[second_index]) as Node2D
			more_spread_before = maxf(more_spread_before, first_more_actor.global_position.distance_to(second_more_actor.global_position))
	for _more_toggle in range(10):
		var before_more_positions: Dictionary = {}
		var before_more_targets: Dictionary = {}
		for pet_id in GameState.get_active_pet_ids():
			var more_actor: Node2D = actors.get(pet_id) as Node2D
			before_more_positions[pet_id] = more_actor.global_position
			before_more_targets[pet_id] = more_actor.get("roam_target")
		var more_action_times: Dictionary = aquarium.get("last_action_time_by_name") as Dictionary
		more_action_times["more"] = -999999.0
		aquarium.set("last_action_time_by_name", more_action_times)
		more_button.pressed.emit()
		for pet_id in GameState.get_active_pet_ids():
			var more_actor: Node2D = actors.get(pet_id) as Node2D
			immediate_panel_positions_stable = immediate_panel_positions_stable and more_actor.global_position.distance_to(before_more_positions[pet_id]) <= 0.01
			more_targets_stable = more_targets_stable and more_actor.get("roam_target") == before_more_targets[pet_id]
			more_toggle_position_log.append("more-open-cycle=%d id=%s position=%s" % [_more_toggle, pet_id, str(more_actor.global_position)])
		(aquarium.get_node("%BackToPrimaryButton") as Button).pressed.emit()
		for pet_id in GameState.get_active_pet_ids():
			var more_actor: Node2D = actors.get(pet_id) as Node2D
			immediate_panel_positions_stable = immediate_panel_positions_stable and more_actor.global_position.distance_to(before_more_positions[pet_id]) <= 0.01
			more_targets_stable = more_targets_stable and more_actor.get("roam_target") == before_more_targets[pet_id]
			more_toggle_position_log.append("more-close-cycle=%d id=%s position=%s" % [_more_toggle, pet_id, str(more_actor.global_position)])
	var more_spread_after: float = 0.0
	for first_index in range(pet_ids_for_more.size()):
		for second_index in range(first_index + 1, pet_ids_for_more.size()):
			var first_more_actor: Node2D = actors.get(pet_ids_for_more[first_index]) as Node2D
			var second_more_actor: Node2D = actors.get(pet_ids_for_more[second_index]) as Node2D
			more_spread_after = maxf(more_spread_after, first_more_actor.global_position.distance_to(second_more_actor.global_position))
	var more_distribution_stable: bool = more_spread_before >= 100.0 and more_spread_after >= more_spread_before - 0.01
	_expect(immediate_panel_positions_stable and panel_targets_stable and more_targets_stable and more_distribution_stable and more_toggle_position_log.size() == pet_ids_for_more.size() * 20, "Ten More open/close cycles preserve all pet positions and swim targets without clustering them")
	for more_position in more_toggle_position_log:
		print("G1 More toggle position: %s" % more_position)
	for pet_id in GameState.get_active_pet_ids():
		var toggle_actor: Node2D = actors.get(pet_id) as Node2D
		var toggle_snapshot: Dictionary = toggle_actor_snapshots.get(pet_id, {}) as Dictionary
		toggle_actor.position = toggle_snapshot.get("position", toggle_actor.position)
		toggle_actor.set("roam_target", toggle_snapshot.get("roam_target", toggle_actor.get("roam_target")))
	aquarium.call("_update_selection_markers")
	aquarium.call("_apply_responsive_layout")
	more_items = aquarium.get_node("%MoreItems") as HBoxContainer
	var time_scale_button: Button = aquarium.get_node("%TimeScaleButton") as Button
	var time_scale_indicator: Label = aquarium.get_node("%TimeScaleIndicator") as Label
	var time_scale_action_times: Dictionary = aquarium.get("last_action_time_by_name") as Dictionary
	time_scale_action_times["more"] = -999999.0
	aquarium.set("last_action_time_by_name", time_scale_action_times)
	more_button.pressed.emit()
	var time_scale_controls_in_more: bool = time_scale_button.get_parent() == more_items and more_items.visible and aquarium.get_node_or_null("%CookieButton") == null
	var scale_test_drop: Dictionary = GameState.reserve_food_drop("food_basic", Vector2.ZERO, Time.get_unix_time_from_system() + 60.0)
	var scale_test_token: String = str(scale_test_drop.get("token_id", ""))
	var scale_expiry_before: float = float(scale_test_drop.get("expires_at", 0.0))
	time_scale_action_times = aquarium.get("last_action_time_by_name") as Dictionary
	time_scale_action_times["time_scale"] = -999999.0
	aquarium.set("last_action_time_by_name", time_scale_action_times)
	time_scale_button.pressed.emit()
	var scale_now: float = Time.get_unix_time_from_system()
	var scale_drop: Dictionary = {}
	for drop in GameState.get_food_drops():
		if str(drop.get("token_id", "")) == scale_test_token:
			scale_drop = drop
			break
	var scale_expiry_after: float = float(scale_drop.get("expires_at", 0.0))
	var scaled_drop_lifetime_valid: bool = not scale_test_token.is_empty() and absf((scale_expiry_after - scale_now) - (scale_expiry_before - scale_now) / 60.0) <= 0.25
	var time_scale_60_visible: bool = TimeManager.get_time_scale() == 60 and time_scale_button.text == "測試加速 ×60" and time_scale_indicator.visible and time_scale_indicator.text == "測試加速 ×60"
	var time_scale_active_water: Rect2 = aquarium.get("active_water_rect")
	var time_scale_indicator_in_corner: bool = time_scale_indicator.position.x >= time_scale_active_water.position.x and time_scale_indicator.position.x + time_scale_indicator.size.x <= time_scale_active_water.end.x
	var scale_not_in_save: bool = not GameState.to_save_dict().has("time_scale") and not GameState.to_save_dict().has("time_scale_factor")
	time_scale_action_times = aquarium.get("last_action_time_by_name") as Dictionary
	time_scale_action_times["time_scale"] = -999999.0
	aquarium.set("last_action_time_by_name", time_scale_action_times)
	time_scale_button.pressed.emit()
	var time_scale_1_visible: bool = TimeManager.get_time_scale() == 1 and time_scale_button.text == "測試加速 ×1" and not time_scale_indicator.visible
	GameState.resolve_food_drop(scale_test_token)
	SaveManager.save_game()
	TimeManager.set_time_scale(1)
	_expect(time_scale_controls_in_more and time_scale_60_visible and time_scale_1_visible and scaled_drop_lifetime_valid and time_scale_indicator_in_corner and scale_not_in_save, "The More-row ×1/×60 test control updates a corner indicator, rescales drop lifetime, and never serializes the multiplier")
	(aquarium.get_node("%BackToPrimaryButton") as Button).pressed.emit()
	aquarium.call("_set_pet_info_open", true)
	var visible_water: Rect2 = aquarium.get("active_water_rect")
	var open_info_panel: Control = aquarium.get_node("%InfoExpandedPanel") as Control
	var open_info_panel_rect: Rect2 = open_info_panel.get_global_rect()
	var visible_water_candidates: Array[Vector2] = []
	for y_ratio in [0.2, 0.5, 0.8]:
		for x_ratio in [0.65, 0.8, 0.95]:
			visible_water_candidates.append(visible_water.position + visible_water.size * Vector2(x_ratio, y_ratio))
	var empty_visible_water_point: Vector2 = Vector2.ZERO
	var found_empty_visible_water_point: bool = false
	for candidate in visible_water_candidates:
		if not bool(aquarium.call("_is_visible_water_point", candidate)):
			continue
		var candidate_hits_actor: bool = false
		for pet_id in GameState.get_active_pet_ids():
			var candidate_actor: Node2D = actors.get(pet_id) as Node2D
			candidate_hits_actor = candidate_hits_actor or (candidate_actor != null and bool(candidate_actor.call("contains_screen_point", candidate, 56.0)))
		if not candidate_hits_actor:
			empty_visible_water_point = candidate
			found_empty_visible_water_point = true
			break
	var food_count_before_visible_tap: int = GameState.get_food_drops().size()
	var visible_water_tap: InputEventScreenTouch = InputEventScreenTouch.new()
	visible_water_tap.pressed = true
	visible_water_tap.position = empty_visible_water_point
	if found_empty_visible_water_point:
		aquarium.call("_unhandled_input", visible_water_tap)
	var food_count_after_visible_tap: int = GameState.get_food_drops().size()
	var panel_water_tap: InputEventScreenTouch = InputEventScreenTouch.new()
	panel_water_tap.pressed = true
	panel_water_tap.position = open_info_panel_rect.get_center()
	aquarium.call("_unhandled_input", panel_water_tap)
	var food_count_after_panel_tap: int = GameState.get_food_drops().size()
	var visible_water_tap_valid: bool = found_empty_visible_water_point and food_count_after_visible_tap == food_count_before_visible_tap + 1
	var panel_water_tap_blocked: bool = food_count_after_panel_tap == food_count_after_visible_tap and not bool(aquarium.call("_is_visible_water_point", open_info_panel_rect.get_center()))
	if not visible_water_tap_valid or not panel_water_tap_blocked:
		print("G1 visible-water tap diagnostic: found=%s point=%s active_water=%s panel=%s visible_point=%s pending=%s last_kind=%d last_at=%d counts=%d/%d/%d panel_is_visible=%s" % [str(found_empty_visible_water_point), str(empty_visible_water_point), str(visible_water), str(open_info_panel_rect), str(aquarium.call("_is_visible_water_point", empty_visible_water_point)), str(aquarium.get("world_input_pair_pending")), int(aquarium.get("last_world_input_kind")), int(aquarium.get("last_world_input_at")), food_count_before_visible_tap, food_count_after_visible_tap, food_count_after_panel_tap, str(open_info_panel.is_visible_in_tree())])
	for tap_drop in GameState.get_food_drops():
		GameState.resolve_food_drop(str(tap_drop.get("token_id", "")))
	SaveManager.save_game()
	_expect(visible_water_tap_valid and panel_water_tap_blocked, "With the information panel open, an empty visible-water tap drops one food and a panel tap drops none")
	aquarium.call("_set_pet_info_open", false)
	await get_tree().process_frame
	pet_growth_bar = aquarium.get_node("%PetGrowthBar") as ProgressBar
	pet_info_button = aquarium.get_node("%PetInfoButton") as Button
	var last_action_by_name: Dictionary = aquarium.get("last_action_time_by_name") as Dictionary
	last_action_by_name["pet_info"] = -999999.0
	aquarium.set("last_action_time_by_name", last_action_by_name)
	var growth_bar_global_rect: Rect2 = pet_growth_bar.get_global_rect()
	var pet_info_button_hit_rect: Rect2 = pet_info_button.get_global_rect()
	var growth_bar_hit_region_valid: bool = pet_growth_bar.get_parent().get_parent() == pet_info_button
	var growth_bar_hit_intersection: Rect2 = pet_info_button_hit_rect.intersection(growth_bar_global_rect)
	var growth_bar_rect_fully_inside_hit_region: bool = growth_bar_hit_intersection == growth_bar_global_rect
	if not growth_bar_rect_fully_inside_hit_region:
		print("G1 growth-bar rect diagnostic: bar=%s button_hit=%s intersection=%s" % [str(growth_bar_global_rect), str(pet_info_button_hit_rect), str(growth_bar_hit_intersection)])
	growth_bar_hit_region_valid = growth_bar_hit_region_valid and growth_bar_rect_fully_inside_hit_region
	growth_bar_hit_region_valid = growth_bar_hit_region_valid and pet_growth_bar.mouse_filter == Control.MOUSE_FILTER_PASS
	growth_bar_hit_region_valid = growth_bar_hit_region_valid and (pet_growth_bar.get_parent() as Control).mouse_filter == Control.MOUSE_FILTER_PASS
	growth_bar_hit_region_valid = growth_bar_hit_region_valid and (pet_growth_bar.get_parent().get_node("PetSummaryLabel") as Control).mouse_filter == Control.MOUSE_FILTER_PASS
	growth_bar_hit_region_valid = growth_bar_hit_region_valid and pet_info_button.is_visible_in_tree() and not pet_info_button.disabled
	growth_bar_hit_region_valid = growth_bar_hit_region_valid and pet_info_button.pressed.is_connected(Callable(aquarium, "_on_pet_info_toggle_pressed"))
	var hud_food_count_before_growth_tap: int = GameState.get_food_drops().size()
	pet_info_button.pressed.emit()
	var growth_bar_activation_opened_info: bool = bool(aquarium.get("pet_info_open"))
	var growth_bar_activation_did_not_drop_food: bool = GameState.get_food_drops().size() == hud_food_count_before_growth_tap
	_expect(growth_bar_hit_region_valid and growth_bar_activation_opened_info and growth_bar_activation_did_not_drop_food, "PetGrowthBar hit region is inside a connected information button that opens without creating food")
	aquarium.call("_set_pet_info_open", false)
	var eviction_pet_id: String = GameState.get_active_pet_ids()[0]
	var eviction_actor: Node2D = actors.get(eviction_pet_id) as Node2D
	var eviction_actor_snapshots: Dictionary = {}
	var eviction_food_claims_snapshot: Dictionary = (aquarium.get("food_claims") as Dictionary).duplicate(true)
	for test_pet_id in GameState.get_active_pet_ids():
		var test_actor: Node2D = actors.get(test_pet_id) as Node2D
		eviction_actor_snapshots[test_pet_id] = {
			"position": test_actor.position,
			"roam_target": test_actor.get("roam_target"),
			"behavior_state": test_actor.get("behavior_state"),
			"food_drop_id": test_actor.get("food_drop_id"),
			"full_food_drop_id": test_actor.get("full_food_drop_id"),
			"idle_time": test_actor.get("idle_time"),
			"layout_transition_active": test_actor.get("layout_transition_active"),
			"panel_evasion_active": test_actor.get("panel_evasion_active"),
			"panel_evasion_target": test_actor.get("panel_evasion_target"),
		}
		test_actor.set("layout_transition_active", false)
		test_actor.set("food_drop_id", "")
		test_actor.set("full_food_drop_id", "")
		test_actor.call("clear_panel_evasion")
	aquarium.call("_set_pet_info_open", true)
	var eviction_open_water: Rect2 = aquarium.get("active_water_rect")
	var eviction_panel_rect: Rect2 = (aquarium.get_node("%InfoExpandedPanel") as Control).get_global_rect()
	var eviction_body_half: Vector2 = eviction_actor.call("_get_conservative_half_extents")
	var eviction_safe_x: float = clampf(eviction_panel_rect.end.x + eviction_body_half.x + 90.0, eviction_open_water.position.x + eviction_body_half.x, eviction_open_water.end.x - eviction_body_half.x)
	var eviction_overlap: Rect2 = eviction_panel_rect.intersection(eviction_open_water)
	var eviction_test_position: Vector2 = eviction_overlap.get_center()
	var eviction_start_found: bool = false
	var eviction_candidate_xs: Array[float] = [eviction_overlap.get_center().x, eviction_overlap.position.x + eviction_body_half.x, eviction_overlap.end.x - eviction_body_half.x]
	var eviction_candidate_ys: Array[float] = [eviction_overlap.get_center().y, eviction_open_water.position.y + eviction_body_half.y + 1.0, eviction_open_water.end.y - eviction_body_half.y - 1.0]
	for candidate_y in eviction_candidate_ys:
		for candidate_x in eviction_candidate_xs:
			var candidate_center: Vector2 = Vector2(
				clampf(candidate_x, eviction_open_water.position.x + eviction_body_half.x, eviction_open_water.end.x - eviction_body_half.x),
				clampf(candidate_y, eviction_open_water.position.y + eviction_body_half.y, eviction_open_water.end.y - eviction_body_half.y)
			)
			eviction_actor.global_position = candidate_center
			var candidate_body: Rect2 = eviction_actor.call("get_visual_body_rect_global")
			if bool(aquarium.call("_rect_fits_inside", candidate_body, eviction_open_water)) and candidate_body.intersects(eviction_panel_rect):
				eviction_test_position = candidate_center
				eviction_start_found = true
				break
		if eviction_start_found:
			break
	var eviction_food_target: Vector2 = Vector2(minf(eviction_open_water.end.x - eviction_body_half.x - 20.0, eviction_safe_x + 200.0), eviction_open_water.get_center().y)
	var eviction_food_drop: Dictionary = GameState.reserve_food_drop("food_basic", eviction_food_target, Time.get_unix_time_from_system() + 60.0)
	var eviction_food_token: String = str(eviction_food_drop.get("token_id", ""))
	var test_food_claims: Dictionary = {}
	if not eviction_food_token.is_empty():
		test_food_claims[eviction_food_token] = eviction_pet_id
	aquarium.set("food_claims", test_food_claims)
	for test_index in range(GameState.get_active_pet_ids().size()):
		var test_pet_id: String = GameState.get_active_pet_ids()[test_index]
		var test_actor: Node2D = actors.get(test_pet_id) as Node2D
		if test_pet_id == eviction_pet_id:
			test_actor.global_position = eviction_test_position
			test_actor.set("food_drop_id", eviction_food_token)
			test_actor.set("roam_target", eviction_food_target)
			test_actor.set("behavior_state", "approach_food")
		else:
			var outside_y: float = clampf(eviction_open_water.get_center().y + float(test_index) * 80.0, eviction_open_water.position.y + 60.0, eviction_open_water.end.y - 60.0)
			test_actor.global_position = Vector2(eviction_safe_x, outside_y)
			test_actor.set("roam_target", Vector2(minf(eviction_open_water.end.x - eviction_body_half.x, eviction_safe_x + 100.0), outside_y))
			test_actor.set("behavior_state", "approach_food")
	var eviction_original_position: Vector2 = eviction_actor.global_position
	var eviction_started_visible: bool = eviction_start_found and bool(aquarium.call("_rect_fits_inside", eviction_actor.call("get_visual_body_rect_global"), eviction_open_water))
	var eviction_was_needed: bool = eviction_actor.call("get_visual_body_rect_global").intersects(eviction_panel_rect)
	var eviction_immediate_delta: float = eviction_actor.global_position.distance_to(eviction_original_position)
	aquarium.call("_update_actor_panel_evasion")
	var eviction_initially_active: bool = bool(eviction_actor.call("is_panel_evasion_active"))
	var outside_pet_id: String = GameState.get_active_pet_ids()[1]
	var outside_actor: Node2D = actors.get(outside_pet_id) as Node2D
	var outside_body_at_start: Rect2 = outside_actor.call("get_visual_body_rect_global")
	var outside_initially_uncovered: bool = not outside_body_at_start.intersects(eviction_panel_rect)
	var outside_initially_idle_of_evasion: bool = not bool(outside_actor.call("is_panel_evasion_active"))
	var eviction_frame_delta: float = 1.0 / 60.0
	var normal_swim_speed: float = float(GameApp.get_balance_value("actor_swim_speed", 32.0))
	var food_chase_speed: float = float(GameApp.get_balance_value("actor_food_chase_speed", 68.0))
	var eviction_speed_valid: bool = true
	var outside_never_evaded: bool = outside_initially_idle_of_evasion
	var eviction_food_claim_preserved: bool = not eviction_food_token.is_empty()
	var eviction_arrival_frame: int = -1
	var post_evasion_movement: float = 0.0
	var eviction_reached_safe_water: bool = false
	for eviction_frame in range(600):
		aquarium.call("_update_actor_panel_evasion")
		if eviction_arrival_frame < 0 and not bool(eviction_actor.call("is_panel_evasion_active")):
			eviction_arrival_frame = eviction_frame
		var frame_start: Vector2 = eviction_actor.global_position
		var outside_frame_start: Vector2 = outside_actor.global_position
		eviction_actor.call("_process", eviction_frame_delta)
		outside_actor.call("_process", eviction_frame_delta)
		var frame_distance: float = eviction_actor.global_position.distance_to(frame_start)
		var outside_frame_distance: float = outside_actor.global_position.distance_to(outside_frame_start)
		var eviction_max_speed: float = normal_swim_speed if bool(eviction_actor.call("is_panel_evasion_active")) else food_chase_speed
		eviction_speed_valid = eviction_speed_valid and frame_distance <= eviction_max_speed * eviction_frame_delta + 0.01
		eviction_speed_valid = eviction_speed_valid and outside_frame_distance <= food_chase_speed * eviction_frame_delta + 0.01
		eviction_food_claim_preserved = eviction_food_claim_preserved and str(eviction_actor.get("food_drop_id")) == eviction_food_token and str((aquarium.get("food_claims") as Dictionary).get(eviction_food_token, "")) == eviction_pet_id
		if eviction_arrival_frame >= 0:
			post_evasion_movement += frame_distance
		var eviction_body_after_frame: Rect2 = eviction_actor.call("get_visual_body_rect_global")
		var outside_body_after_frame: Rect2 = outside_actor.call("get_visual_body_rect_global")
		eviction_reached_safe_water = eviction_reached_safe_water or (not bool(eviction_actor.call("is_panel_evasion_active")) and not eviction_body_after_frame.intersects(eviction_panel_rect))
		outside_never_evaded = outside_never_evaded and not bool(outside_actor.call("is_panel_evasion_active")) and not outside_body_after_frame.intersects(eviction_panel_rect)
	var eviction_preserved_target: bool = eviction_actor.get("roam_target") == eviction_food_target and eviction_initially_active
	var eviction_resumed_movement: bool = eviction_arrival_frame >= 0 and post_evasion_movement >= 32.0
	var eviction_open_position: Vector2 = eviction_actor.global_position
	aquarium.call("_set_pet_info_open", false)
	var eviction_close_delta: float = eviction_actor.global_position.distance_to(eviction_open_position)
	var eviction_resumed_target: bool = eviction_actor.get("roam_target") == eviction_food_target and str(eviction_actor.get("food_drop_id")) == eviction_food_token and not bool(eviction_actor.call("is_panel_evasion_active"))
	var eviction_probe_result: bool = not eviction_food_token.is_empty() and eviction_started_visible and eviction_was_needed and eviction_immediate_delta <= 0.01 and eviction_speed_valid and eviction_reached_safe_water and eviction_resumed_movement and eviction_preserved_target and eviction_food_claim_preserved and outside_initially_uncovered and outside_never_evaded and eviction_close_delta <= 0.01 and eviction_resumed_target
	if not eviction_probe_result:
		print("G1 panel-evasion diagnostic: token=%s panel_opaque=%s panel_rect=%s water=%s body_start=%s safe_target=%s started_visible=%s obscured=%s active=%s speed=%s reached=%s resumed_distance=%.2f target_preserved=%s claim_preserved=%s outside_clear=%s outside_never_evaded=%s close_delta=%.3f restored_target=%s" % [eviction_food_token, str(aquarium.call("_is_info_panel_opaque")), str(eviction_panel_rect), str(eviction_open_water), str(eviction_actor.call("get_visual_body_rect_global")), str(eviction_actor.get("panel_evasion_target")), str(eviction_started_visible), str(eviction_was_needed), str(eviction_initially_active), str(eviction_speed_valid), str(eviction_reached_safe_water), post_evasion_movement, str(eviction_preserved_target), str(eviction_food_claim_preserved), str(outside_initially_uncovered), str(outside_never_evaded), eviction_close_delta, str(eviction_resumed_target)])
	_expect(eviction_probe_result, "During ten open-panel seconds only an obscured pet evades, retains its feed claim/target, reaches visible water and resumes normal chase movement")
	if not eviction_food_token.is_empty():
		GameState.resolve_food_drop(eviction_food_token)
		(aquarium.get("food_claims") as Dictionary).erase(eviction_food_token)
		aquarium.call("_update_food_drops", 0.0)
	SaveManager.save_game()
	aquarium.set("food_claims", eviction_food_claims_snapshot)
	for test_pet_id in GameState.get_active_pet_ids():
		var restore_actor: Node2D = actors.get(test_pet_id) as Node2D
		var actor_snapshot: Dictionary = eviction_actor_snapshots.get(test_pet_id, {}) as Dictionary
		restore_actor.position = actor_snapshot.get("position", restore_actor.position)
		restore_actor.set("roam_target", actor_snapshot.get("roam_target", restore_actor.get("roam_target")))
		restore_actor.set("behavior_state", actor_snapshot.get("behavior_state", restore_actor.get("behavior_state")))
		restore_actor.set("food_drop_id", actor_snapshot.get("food_drop_id", restore_actor.get("food_drop_id")))
		restore_actor.set("full_food_drop_id", actor_snapshot.get("full_food_drop_id", restore_actor.get("full_food_drop_id")))
		restore_actor.set("idle_time", actor_snapshot.get("idle_time", restore_actor.get("idle_time")))
		restore_actor.set("layout_transition_active", actor_snapshot.get("layout_transition_active", false))
		restore_actor.set("panel_evasion_active", actor_snapshot.get("panel_evasion_active", false))
		restore_actor.set("panel_evasion_target", actor_snapshot.get("panel_evasion_target", restore_actor.global_position))
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
	var first_detail_pet: Dictionary = GameState.get_pet(selected_id)
	first_detail_pet["mood"] = 85
	first_detail_pet["growth_exp"] = 6
	var first_detail_care: Dictionary = GameState.get_current_care_stats(selected_id)
	first_detail_care["touch_growth_exp_hour"] = 5
	first_detail_care["touch_exp_hour_started_at"] = Time.get_unix_time_from_system() - 120.0
	GameState.set_pet_and_care_stats(selected_id, first_detail_pet, first_detail_care)
	var second_detail_pet: Dictionary = GameState.get_pet(second_id)
	second_detail_pet["mood"] = 70
	second_detail_pet["growth_exp"] = 0
	var second_next_stage: Dictionary = EvolutionSystem.get_next_stage_data(second_id)
	var second_next_growth_exp: int = max(1, int(second_next_stage.get("required_growth_exp", 0)))
	var second_detail_care: Dictionary = GameState.get_current_care_stats(second_id)
	second_detail_care["touch_growth_exp_hour"] = 0
	second_detail_care["touch_exp_hour_started_at"] = 0.0
	GameState.set_pet_and_care_stats(second_id, second_detail_pet, second_detail_care)
	GameState.set_selected_pet_id(selected_id)
	aquarium.call("_refresh", false)
	var countdown_before: String = str((aquarium.get_node("%TouchExpLabel") as Label).text)
	await get_tree().create_timer(1.1).timeout
	aquarium.call("_refresh_touch_exp_label")
	var countdown_after: String = str((aquarium.get_node("%TouchExpLabel") as Label).text)
	_expect(countdown_before != countdown_after and countdown_before.contains("5/60") and countdown_after.contains("5/60"), "Selected pet hourly touch-expiry countdown advances once per second")
	second_pet_button.pressed.emit()
	var second_detail_labels: bool = GameState.get_selected_pet_id() == second_id
	second_detail_labels = second_detail_labels and str((aquarium.get_node("%PetNameLabel") as Label).text) == str(second_detail_pet.get("nickname", ""))
	second_detail_labels = second_detail_labels and str((aquarium.get_node("%GenderPlaceholderLabel") as Label).text) == "性別：—"
	second_detail_labels = second_detail_labels and str((aquarium.get_node("%StageLabel") as Label).text).begins_with("階段 1 · ")
	second_detail_labels = second_detail_labels and str((aquarium.get_node("%MoodLabel") as Label).text) == "心情：70 / 100"
	second_detail_labels = second_detail_labels and str((aquarium.get_node("%ExpLabel") as Label).text) == "成長經驗：0 / %d" % second_next_growth_exp
	second_detail_labels = second_detail_labels and is_equal_approx((aquarium.get_node("%GrowthExpBar") as ProgressBar).value, 0.0)
	second_detail_labels = second_detail_labels and str((aquarium.get_node("%TouchExpLabel") as Label).text) == "摸摸經驗：0/60｜可累積"
	_expect(second_detail_labels, "Selecting the second pet immediately refreshes its name, mood, growth EXP, and touch-expiry state")
	GameState.set_selected_pet_id(selected_id)
	var nursery_button: Button = aquarium.get_node("%NurseryButton") as Button
	_expect(nursery_button.disabled and GameState.get_nursery_eggs().is_empty() and nursery_button.text == "育嬰室（0）" and nursery_button.tooltip_text == "沒有蛋了", "Nursery keeps its counted action label at zero eggs, disables activation and reports that no eggs remain")
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
		if pet_id != GameState.get_active_pet_ids()[0]:
			await get_tree().create_timer(0.55).timeout
		_expect(str(actor.get("pet_id")) == pet_id, "%s actor has an explicit matching pet_id" % pet_id)
		_expect(int(actor.get("current_stage")) == int(GameState.get_pet(pet_id).get("stage", 0)), "%s actor uses its bound stage" % pet_id)
		var start_position: Vector2 = (actor as Node2D).global_position
		hunger_before_by_pet[pet_id] = int(GameState.get_pet(pet_id).get("hunger", 0))
		var touch_pet_before: Dictionary = GameState.get_pet(pet_id)
		var mood_before_touch: int = int(touch_pet_before.get("mood", 0))
		var growth_before_touch: int = int(touch_pet_before.get("growth_exp", 0))
		var touch_care_before: Dictionary = GameState.get_current_care_stats(pet_id)
		var touch_now_seconds: float = Time.get_unix_time_from_system()
		var touch_reset_seconds: float = maxf(float(GameApp.get_balance_value("touch_exp_reset_seconds")), 1.0)
		var touch_window_start: float = float(touch_care_before.get("touch_exp_hour_started_at", 0.0))
		var touch_window_expired: bool = touch_window_start <= 0.0 or touch_now_seconds < touch_window_start or touch_now_seconds - touch_window_start >= touch_reset_seconds
		var touch_exp_used: int = 0 if touch_window_expired else int(touch_care_before.get("touch_growth_exp_hour", 0))
		var touch_exp_cap: int = int(GameApp.get_balance_value("touch_growth_exp_cap"))
		var expected_touch_mood: int = mini(int(GameApp.get_balance_value("max_mood")), mood_before_touch + int(GameApp.get_balance_value("touch_mood_add")))
		var expected_touch_exp_gain: int = mini(int(GameApp.get_balance_value("touch_growth_exp_add")), maxi(0, touch_exp_cap - touch_exp_used))
		var food_drops_before_touch: int = GameState.get_food_drops().size()
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
		var touched_pet: Dictionary = GameState.get_pet(pet_id)
		_expect(int(touched_pet.get("mood", 0)) == expected_touch_mood and int(touched_pet.get("growth_exp", 0)) == growth_before_touch + expected_touch_exp_gain, "Touching %s immediately selects and grants the configured mood and hourly-capped EXP" % pet_id)
		_expect(GameState.get_food_drops().size() == food_drops_before_touch, "Touching %s cannot be misinterpreted as a water-food drop" % pet_id)
		var expected_touch_feedback: String
		var actual_mood_gain: int = expected_touch_mood - mood_before_touch
		if expected_touch_exp_gain == 0 and (touch_exp_cap == 0 or touch_exp_used >= touch_exp_cap):
			expected_touch_feedback = "心情 +%d（經驗已達上限）" % actual_mood_gain
		elif actual_mood_gain > 0 and expected_touch_exp_gain > 0:
			expected_touch_feedback = "+%d 心情 +%d 經驗" % [actual_mood_gain, expected_touch_exp_gain]
		elif actual_mood_gain > 0:
			expected_touch_feedback = "+%d 心情" % actual_mood_gain
		else:
			expected_touch_feedback = "+%d 經驗" % expected_touch_exp_gain
		var touch_feedback_visible: bool = false
		for feedback_node in feedback_container.get_children():
			if feedback_node is Label and str((feedback_node as Label).text) == expected_touch_feedback:
				touch_feedback_visible = true
		_expect(touch_feedback_visible and str((aquarium.get_node("%MessageLabel") as Label).text) == expected_touch_feedback, "Successful pet taps show floating feedback with the actual configured mood and EXP gains")
		var paw_anchor: Node2D = actor.get_node_or_null("TouchPawWaveAnchor") as Node2D
		var touch_sprite: Sprite2D = actor.get_node("%Sprite") as Sprite2D
		var expected_paw_anchor: Vector2 = actor.to_local(touch_sprite.to_global(touch_sprite.offset + Vector2(16.0, -23.0) - Vector2(touch_sprite.texture.get_size()) * 0.5))
		var paw_anchor_reserved: bool = paw_anchor != null and paw_anchor.z_index > touch_sprite.z_index and paw_anchor.position.distance_to(expected_paw_anchor) <= 0.01
		var paw_hook_reserved: bool = actor.has_method("_play_touch_paw_wave") and paw_anchor != null and paw_anchor.get_child_count() == 0
		_expect(paw_anchor_reserved and paw_hook_reserved, "Touch keeps the above-head ART-HAND-01 playback hook reserved without integrating an unapproved v4 asset")
		var touch_log_has_pet_id: bool = false
		for touch_log_entry in RuntimeLogger.get_logs():
			if touch_log_entry is Dictionary:
				var touch_log_message: String = str((touch_log_entry as Dictionary).get("message", ""))
				touch_log_has_pet_id = touch_log_has_pet_id or (touch_log_message.contains(pet_id) and (touch_log_message.contains(" touch") or touch_log_message.contains(" mood:") or touch_log_message.contains(" growth_exp:")))
		_expect(touch_log_has_pet_id, "Touch/mood/growth logs identify the affected pet %s" % pet_id)
		if pet_id == first_active_pet_id:
			aquarium.call("_set_pet_info_open", false)
			var growth_before_cooldown: int = int(GameState.get_pet(pet_id).get("growth_exp", 0))
			var cooldown_feedback_count: int = feedback_container.get_child_count()
			var cooldown_paw_wave_count: int = paw_anchor.get_child_count() if paw_anchor != null else -1
			var immediate_retry_succeeded: bool = bool(aquarium.call("_try_touch_pet", pet_id, actor))
			var cooldown_visible: bool = str((aquarium.get_node("%MessageLabel") as Label).text).contains("冷卻")
			_expect(not immediate_retry_succeeded and cooldown_visible and feedback_container.get_child_count() == cooldown_feedback_count and paw_anchor != null and paw_anchor.get_child_count() == cooldown_paw_wave_count and int(GameState.get_pet(pet_id).get("growth_exp", 0)) == growth_before_cooldown, "Touch cooldown refusal is explicit and does not reward or add feedback nodes while the paw-wave hook remains reserved")
			var repeated_touch_sequence_ok: bool = true
			for _repeated_touch in range(2):
				await get_tree().create_timer(0.55).timeout
				var repeated_before: Dictionary = GameState.get_pet(pet_id)
				var repeated_click: InputEventScreenTouch = InputEventScreenTouch.new()
				repeated_click.pressed = true
				repeated_click.position = actor.global_position
				aquarium.call("_unhandled_input", repeated_click)
				var repeated_after: Dictionary = GameState.get_pet(pet_id)
				repeated_touch_sequence_ok = repeated_touch_sequence_ok and GameState.get_selected_pet_id() == pet_id
				var repeated_care_before: Dictionary = GameState.get_current_care_stats(pet_id)
				var repeated_exp_used: int = int(repeated_care_before.get("touch_growth_exp_hour", 0))
				var repeated_exp_gain: int = mini(int(GameApp.get_balance_value("touch_growth_exp_add")), maxi(0, int(GameApp.get_balance_value("touch_growth_exp_cap")) - repeated_exp_used))
				var repeated_mood_gain: int = mini(int(GameApp.get_balance_value("touch_mood_add")), maxi(0, int(GameApp.get_balance_value("max_mood")) - int(repeated_before.get("mood", 0))))
				var repeated_feedback: String = "+%d 心情 +%d 經驗" % [repeated_mood_gain, repeated_exp_gain]
				repeated_touch_sequence_ok = repeated_touch_sequence_ok and int(repeated_after.get("growth_exp", 0)) == int(repeated_before.get("growth_exp", 0)) + repeated_exp_gain
				repeated_touch_sequence_ok = repeated_touch_sequence_ok and int(repeated_after.get("mood", 0)) == int(repeated_before.get("mood", 0)) + repeated_mood_gain
				repeated_touch_sequence_ok = repeated_touch_sequence_ok and str((aquarium.get_node("%MessageLabel") as Label).text) == repeated_feedback
				aquarium.call("_set_pet_info_open", false)
			_expect(repeated_touch_sequence_ok, "Two repeated pet taps separated by 0.55 seconds each independently grant the documented mood and EXP feedback")
		aquarium.call("_set_pet_info_open", false)
		var old_hunger: int = int(GameState.get_pet(pet_id).get("hunger", 0))
		var old_inventory: int = GameState.get_inventory_count("food_basic")
		var actions: Dictionary = aquarium.get("last_action_time_by_name") as Dictionary
		actions["feed"] = -999999.0
		aquarium.set("last_action_time_by_name", actions)
		aquarium.call("_on_feed_pressed")
		_expect(int(GameState.get_pet(pet_id).get("hunger", 0)) == old_hunger, "Dropped food waits for an actor to eat")
		_expect(GameState.get_food_drops().size() == GameState.get_active_pet_ids().find(pet_id) + 1, "Feed button creates one persisted food token")
		_expect(GameState.get_inventory_count("food_basic") == old_inventory, "One unlimited-food drop leaves the legacy quantity unchanged")
	_expect(GameState.get_food_drops().size() == 3 and GameState.get_food_drops().size() < GameState.get_max_active_food_drops(), "Three live feed actions remain below the configured %d-token cap" % GameState.get_max_active_food_drops())
	_expect(GameState.get_inventory_count("food_basic") == food_quantity_before_world_feeds, "Three drops preserve the legacy unlimited-food quantity")
	var capped_touch_pet_id: String = GameState.get_active_pet_ids()[0]
	var capped_touch_actor: Node2D = actors.get(capped_touch_pet_id) as Node2D
	var capped_touch_original_pet: Dictionary = GameState.get_pet(capped_touch_pet_id)
	var capped_touch_original_care: Dictionary = GameState.get_current_care_stats(capped_touch_pet_id)
	var capped_touch_pet: Dictionary = capped_touch_original_pet.duplicate(true)
	capped_touch_pet["mood"] = 70
	var capped_touch_care: Dictionary = capped_touch_original_care.duplicate(true)
	var capped_touch_now: float = Time.get_unix_time_from_system()
	capped_touch_care["touch_growth_exp_hour"] = int(GameApp.get_balance_value("touch_growth_exp_cap"))
	capped_touch_care["touch_exp_hour_started_at"] = capped_touch_now
	capped_touch_care["touch_exp_hour_id"] = str(capped_touch_now)
	capped_touch_care["last_touch_effect_at"] = capped_touch_now - float(GameApp.get_balance_value("touch_cooldown_seconds")) - 0.01
	GameState.set_pet_and_care_stats(capped_touch_pet_id, capped_touch_pet, capped_touch_care)
	aquarium.set("touch_cooldown", 0.0)
	var capped_touch_growth_before: int = int(GameState.get_pet(capped_touch_pet_id).get("growth_exp", 0))
	var capped_touch_succeeded: bool = bool(aquarium.call("_try_touch_pet", capped_touch_pet_id, capped_touch_actor))
	var capped_touch_mood: int = mini(int(GameApp.get_balance_value("max_mood")), 70 + int(GameApp.get_balance_value("touch_mood_add")))
	var capped_touch_mood_gain: int = capped_touch_mood - 70
	var capped_touch_expected_feedback: String = "心情 +%d（經驗已達上限）" % capped_touch_mood_gain
	var capped_touch_feedback: bool = str((aquarium.get_node("%MessageLabel") as Label).text) == capped_touch_expected_feedback
	for capped_feedback_node in feedback_container.get_children():
		if capped_feedback_node is Label and str((capped_feedback_node as Label).text) == capped_touch_expected_feedback:
			capped_touch_feedback = true
	capped_touch_feedback = capped_touch_feedback and int(GameState.get_pet(capped_touch_pet_id).get("mood", 0)) == capped_touch_mood
	capped_touch_feedback = capped_touch_feedback and int(GameState.get_pet(capped_touch_pet_id).get("growth_exp", 0)) == capped_touch_growth_before
	capped_touch_feedback = capped_touch_feedback and int(GameState.get_current_care_stats(capped_touch_pet_id).get("touch_growth_exp_hour", 0)) == int(GameApp.get_balance_value("touch_growth_exp_cap"))
	_expect(capped_touch_succeeded and capped_touch_feedback, "Touch at the hourly EXP cap still grants actual mood and clearly reports that EXP is capped")
	GameState.set_pet_and_care_stats(capped_touch_pet_id, capped_touch_original_pet, capped_touch_original_care)
	aquarium.call("_refresh", false)
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
	var empty_water_candidates: Array[Vector2] = [
		active_water.position + Vector2(72.0, 72.0),
		Vector2(active_water.end.x - 72.0, active_water.position.y + 72.0),
		Vector2(active_water.position.x + 72.0, active_water.end.y - 72.0),
		active_water.end - Vector2(72.0, 72.0),
	]
	var water_tap: Vector2 = active_water.get_center()
	var empty_water_found: bool = false
	for candidate_water_tap in empty_water_candidates:
		var candidate_clear: bool = active_water.has_point(candidate_water_tap)
		var candidate_hit_area: Rect2 = Rect2(candidate_water_tap - Vector2(64.0, 64.0), Vector2(128.0, 128.0))
		for pet_id in GameState.get_active_pet_ids():
			var touch_candidate_actor: Node2D = actors.get(pet_id) as Node2D
			if touch_candidate_actor != null and candidate_hit_area.intersects(touch_candidate_actor.call("get_visual_body_rect_global")):
				candidate_clear = false
		if candidate_clear:
			water_tap = candidate_water_tap
			empty_water_found = true
			break
	_expect(empty_water_found, "The empty-water test chooses a tap target outside all pet hit areas")
	var pet_stats_before_water_tap: Dictionary = {}
	for pet_id in GameState.get_active_pet_ids():
		var water_pet: Dictionary = GameState.get_pet(pet_id)
		pet_stats_before_water_tap[pet_id] = [int(water_pet.get("mood", 0)), int(water_pet.get("growth_exp", 0))]
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
	var empty_tap_did_not_touch_pet: bool = true
	for pet_id in GameState.get_active_pet_ids():
		var current_water_pet: Dictionary = GameState.get_pet(pet_id)
		var previous_water_stats: Array = pet_stats_before_water_tap[pet_id] as Array
		empty_tap_did_not_touch_pet = empty_tap_did_not_touch_pet and int(current_water_pet.get("mood", 0)) == int(previous_water_stats[0]) and int(current_water_pet.get("growth_exp", 0)) == int(previous_water_stats[1])
	_expect(delayed_pair_elapsed_msec >= 240 and GameState.get_food_drops().size() == 1 and empty_tap_did_not_touch_pet, "An empty-water tap creates one food token without touching any pet")
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
	_run_g1_fix_26_mixed_stability_case(aquarium, actor_anchor, actors)
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
		var panel_pet_id: String = GameState.get_selected_pet_id()
		var panel_meal_consumed: bool = FoodDropSystem.consume_food(panel_drop_token, panel_pet_id)
		var panel_meal_drop: Dictionary = CoinDropSystem.get_meal_coin_drop(panel_drop_token)
		var panel_meal_value: int = int(GameApp.get_balance_value("meal_coin_base_value")) + int(GameState.get_pet(panel_pet_id).get("stage", 1))
		var panel_meal_coin_token: String = str(panel_meal_drop.get("token_id", ""))
		_expect(panel_meal_consumed and str(panel_meal_drop.get("source", "")) == "meal" and str(panel_meal_drop.get("food_token_id", "")) == panel_drop_token and int(panel_meal_drop.get("value", 0)) == panel_meal_value, "Consumed panel food creates one correctly valued meal coin")
		if not panel_meal_coin_token.is_empty():
			var panel_coin_before: int = GameState.get_currency("bubble_coin")
			var panel_meal_collection: Dictionary = CoinDropSystem.collect_coin(panel_meal_coin_token, false)
			var panel_meal_replay: Dictionary = CoinDropSystem.collect_coin(panel_meal_coin_token, false)
			_expect(not panel_meal_collection.is_empty() and GameState.get_currency("bubble_coin") == panel_coin_before + panel_meal_value, "Panel meal coin settles once before unrelated coin-ledger checks")
			_expect(panel_meal_replay.is_empty() and GameState.get_currency("bubble_coin") == panel_coin_before + panel_meal_value, "Panel meal coin replay cannot add a second credit")
		aquarium.call("_update_food_drops", 0.0)

	var coin_bubbles: Dictionary = aquarium.get("coin_bubbles_by_id") as Dictionary
	for existing_coin in GameState.get_coin_drops():
		var existing_token: String = str(existing_coin.get("token_id", ""))
		if existing_token.is_empty():
			continue
		GameState.cancel_coin_drop(existing_token)
		var existing_bubble: Node = coin_bubbles.get(existing_token) as Node
		if is_instance_valid(existing_bubble):
			existing_bubble.queue_free()
		coin_bubbles.erase(existing_token)
	aquarium.set("passive_timer", 0.0)
	var source_pet_id: String = GameState.get_active_pet_ids()[0]
	var source_actor: Node2D = (aquarium.get("actors_by_id") as Dictionary).get(source_pet_id) as Node2D
	var source_pet: Dictionary = GameState.get_pet(source_pet_id)
	source_pet["mood"] = 100
	GameState.set_pet(source_pet_id, source_pet)
	var balance_table: Dictionary = GameApp.get_table("balance")
	balance_table["passive_coin_interval_seconds"] = 1000000
	GameApp.data_tables["balance"] = balance_table
	for stale_coin_fixture in GameState.get_coin_drops():
		var stale_coin_fixture_token: String = str(stale_coin_fixture.get("token_id", ""))
		if not stale_coin_fixture_token.is_empty():
			GameState.cancel_coin_drop(stale_coin_fixture_token)
	var previous_coin_bubbles: Dictionary = aquarium.get("coin_bubbles_by_id") as Dictionary
	for stale_coin_bubble_token in previous_coin_bubbles.keys():
		var stale_coin_bubble: Node = previous_coin_bubbles.get(stale_coin_bubble_token) as Node
		if stale_coin_bubble != null and is_instance_valid(stale_coin_bubble):
			stale_coin_bubble.call("discard")
	previous_coin_bubbles.clear()
	_expect(GameState.get_coin_drops().is_empty() and previous_coin_bubbles.is_empty(), "Manual coin regression isolates the earlier meal and passive coin fixtures")
	balance_table = GameApp.get_table("balance")
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
	_expect(not _coin_drop_is_pending(manual_token), "Collected coin is removed from its durable ledger")
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
	_expect(not (aquarium.get("coin_bubbles_by_id") as Dictionary).has(manual_token), "Restart does not restore a settled coin")
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
	_expect(not _coin_drop_is_pending(pending_coin_token), "Auto-collection settles and removes the coin ledger entry")
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
		pet["hunger"] = int(GameApp.get_balance_value("hungry_hunger_max")) - int(GameApp.get_table("items").get("food_basic", {}).get("hunger_add", 0))
		GameState.set_pet(pet_id, pet)
		var actor: Node2D = (aquarium.get("actors_by_id") as Dictionary).get(pet_id) as Node2D
		if actor != null:
			actor.call("refresh_pet")
	var token_ids: Array[String] = []
	var water: Rect2 = aquarium.get("active_water_rect")
	for drop_index in range(GameState.get_max_active_food_drops()):
		var column: int = drop_index % 5
		var row: int = int(floor(float(drop_index) / 5.0))
		var drop_position: Vector2 = water.position + Vector2(water.size.x * (0.12 + float(column) * 0.18), water.size.y * (0.25 + float(row) * 0.5))
		var drop: Dictionary = FoodDropSystem.drop_food(drop_position)
		var token_id: String = str(drop.get("token_id", ""))
		if not token_id.is_empty():
			token_ids.append(token_id)
	_expect(token_ids.size() == GameState.get_max_active_food_drops() and GameState.get_food_drops().size() == GameState.get_max_active_food_drops(), "Ten distinct food tokens can coexist in the durable ledger")
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
	_expect(reopened_drops.size() == GameState.get_max_active_food_drops() and reopened_token_ids.size() == GameState.get_max_active_food_drops(), "Save validation restores all 10 pending food tokens with unique IDs")
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
	fair_claims = fair_claims and claim_owners.size() == pet_ids.size() and (aquarium.get("food_drop_visuals") as Dictionary).size() == GameState.get_max_active_food_drops()
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
		_expect(settled_once and not replay_settled and GameState.get_food_drops().size() == GameState.get_max_active_food_drops() - 1, "One of 10 restored tokens settles once and its replay is rejected")
		_expect(int(eater_after.get("hunger", 0)) > hunger_before and int(eater_after.get("growth_exp", 0)) == exp_before + food_exp, "Single-token settlement grants exactly one meal benefit")
	else:
		_expect(false, "A restored food token is available for the single-settlement check")
	for drop in GameState.get_food_drops():
		GameState.resolve_food_drop(str(drop.get("token_id", "")))
	aquarium.call("_update_food_drops", 0.0)
	_expect(GameState.get_food_drops().is_empty() and (aquarium.get("food_drop_visuals") as Dictionary).is_empty(), "Consumed and remaining first-batch tokens leave no stale ledger or markers")
	for pet_id in pet_ids:
		var full_pet: Dictionary = GameState.get_pet(pet_id)
		full_pet["hunger"] = int(GameApp.get_balance_value("max_hunger"))
		GameState.set_pet(pet_id, full_pet)
		var actor: Node2D = (aquarium.get("actors_by_id") as Dictionary).get(pet_id) as Node2D
		if actor != null:
			actor.call("refresh_pet")
	water = aquarium.get("active_water_rect")
	var sunk_tokens: Array[String] = []
	for drop_index in range(GameState.get_max_active_food_drops()):
		var drop_position: Vector2 = Vector2(
			water.position.x + water.size.x * (0.08 + float(drop_index) * 0.084),
			water.end.y - 32.0
		)
		var drop: Dictionary = FoodDropSystem.drop_food(drop_position)
		var token_id: String = str(drop.get("token_id", ""))
		if not token_id.is_empty():
			sunk_tokens.append(token_id)
	_expect(sunk_tokens.size() == GameState.get_max_active_food_drops() and GameState.get_food_drops().size() == GameState.get_max_active_food_drops(), "A second batch of 10 pending tokens is accepted for sink cleanup")
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
	hungry_pet["hunger"] = int(GameApp.get_balance_value("hungry_hunger_max")) - int(GameApp.get_table("items").get("food_basic", {}).get("hunger_add", 0))
	GameState.set_pet(hungry_pet_id, hungry_pet)
	var full_pet: Dictionary = GameState.get_pet(full_pet_id)
	full_pet["hunger"] = int(GameApp.get_balance_value("max_hunger"))
	GameState.set_pet(full_pet_id, full_pet)
	for pet_id in pet_ids:
		var actor: Node2D = actors.get(pet_id) as Node2D
		if actor != null:
			actor.call("refresh_pet")
	aquarium.call("_update_hunger_bubbles")
	var hungry_bubbles: Dictionary = aquarium.get("hunger_bubbles_by_id") as Dictionary
	var wants_to_eat_visible_before_meal: bool = int(GameState.get_pet(hungry_pet_id).get("hunger", -1)) == 35
	var hungry_bubble_before_meal: Control = hungry_bubbles.get(hungry_pet_id) as Control
	wants_to_eat_visible_before_meal = wants_to_eat_visible_before_meal and is_instance_valid(hungry_bubble_before_meal) and hungry_bubble_before_meal.visible
	_expect(wants_to_eat_visible_before_meal, "A pet at 35 hunger shows its wants-to-eat bubble before the 35-to-40 meal")
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
	var hungry_hunger_before: int = int(GameState.get_pet(hungry_pet_id).get("hunger", 0))
	var expected_hungry_hunger_after: int = mini(int(GameApp.get_balance_value("max_hunger")), hungry_hunger_before + int(GameApp.get_table("items").get("food_basic", {}).get("hunger_add", 0)))
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
	var hungry_bubble_after_meal: Control = (aquarium.get("hunger_bubbles_by_id") as Dictionary).get(hungry_pet_id) as Control
	var wants_to_eat_hidden_at_40: bool = not is_instance_valid(hungry_bubble_after_meal) or not hungry_bubble_after_meal.visible
	_expect(GameState.get_food_drops().is_empty(), "Hungry pet settles its token once")
	_expect(hungry_hunger_before == 35 and int(hungry_after.get("hunger", 0)) == 40 and int(hungry_after.get("growth_exp", 0)) == hungry_exp_before + expected_exp, "Hungry pet receives one 35-to-40 meal and its configured EXP")
	_expect(int(full_after.get("hunger", 0)) == int(GameApp.get_balance_value("max_hunger")) and int(full_after.get("growth_exp", 0)) == full_exp_before, "Full pet refusal grants no hunger or growth reward")
	_expect(GameState.get_inventory_count("food_basic") == food_quantity_before, "Hungry meal and full refusal leave the legacy quantity unchanged")
	_expect(wants_to_eat_hidden_at_40, "Eating immediately removes the wants-to-eat bubble even when hunger remains 40")
	_expect(str((aquarium.get_node("%MessageLabel") as Label).text).contains("飽足度"), "Eating displays corresponding satiety feedback in Traditional Chinese")
	var food_event_log: String = RuntimeLogger.get_log_text()
	_expect(food_event_log.contains("food eaten %s by %s" % [token_id, hungry_pet_id]), "Successful food consumption logs its token and pet")
	_expect(food_event_log.contains("full refusal %s" % full_pet_id), "Full-pet refusal logs the pet without creating a food claim")
	var hunger_transition: String = "%s hunger %d -> %d" % [hungry_pet_id, hungry_hunger_before, int(hungry_after.get("hunger", 0))]
	_expect(food_event_log.contains(hunger_transition), "Successful food consumption logs its configured hunger transition with the stable pet ID on the same line")
	var hunger_decrease_pet: Dictionary = GameState.get_pet(hungry_pet_id)
	hunger_decrease_pet["hunger"] = 39
	GameState.set_pet(hungry_pet_id, hunger_decrease_pet)
	aquarium.call("_update_hunger_bubbles")
	var hungry_bubble_after_decrease: Control = (aquarium.get("hunger_bubbles_by_id") as Dictionary).get(hungry_pet_id) as Control
	var wants_to_eat_returns_after_decrease: bool = is_instance_valid(hungry_bubble_after_decrease) and hungry_bubble_after_decrease.visible
	var hunger_above_threshold_pet: Dictionary = GameState.get_pet(hungry_pet_id)
	hunger_above_threshold_pet["hunger"] = 41
	GameState.set_pet(hungry_pet_id, hunger_above_threshold_pet)
	aquarium.call("_update_hunger_bubbles")
	var wants_to_eat_hidden_above_40: bool = not (aquarium.get("hunger_bubbles_by_id") as Dictionary).has(hungry_pet_id)
	_expect(wants_to_eat_returns_after_decrease and wants_to_eat_hidden_above_40, "The wants-to-eat bubble returns on the next hunger decrease and is removed above 40")
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
		pet["hunger"] = int(GameApp.get_balance_value("max_hunger"))
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
		_expect(int(full_pet_before_restore.get("hunger", -1)) == int(GameApp.get_balance_value("max_hunger")) and int(full_pet_before_restore.get("growth_exp", -1)) == int(original_pet.get("growth_exp", -2)), "Full-pet refusal grants no hunger or growth reward")
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
		pet["hunger"] = int(GameApp.get_balance_value("max_hunger"))
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
	for drop_index in range(GameState.get_max_active_food_drops()):
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
	_expect(token_ids.size() == GameState.get_max_active_food_drops() and GameState.get_food_drops().size() == GameState.get_max_active_food_drops() and (aquarium.get("food_drop_visuals") as Dictionary).size() == GameState.get_max_active_food_drops(), "All ten full-pet food tokens and pellet visuals are present before refusal feedback")
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
		all_pets_unchanged = all_pets_unchanged and int(pet.get("hunger", 0)) == int(GameApp.get_balance_value("max_hunger")) and int(pet.get("growth_exp", 0)) == int(growth_before_by_pet[pet_id])
	_expect(refusal_bubbles.size() == pet_ids.size() and readable_bubble_count == pet_ids.size() and bubbles_stay_visible and pellets_not_obscured and all_pets_unchanged, "After ten full-pet drops, all three head-following refusal labels stay readable above actors and clear of pellets in the 0–3s window with no settlement")
	_expect(GameState.get_food_drops().size() == GameState.get_max_active_food_drops() and GameState.get_inventory_count("food_basic") == food_quantity_before, "Full ten-token refusal leaves the pending ledger and unlimited legacy quantity unchanged")
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
	test_pet["hunger"] = int(GameApp.get_balance_value("hungry_hunger_max")) - int(GameApp.get_table("items").get("food_basic", {}).get("hunger_add", 0))
	GameState.set_pet(pet_id, test_pet)
	actor.call("refresh_pet")
	actor.call("set_stage", stage, str(test_pet.get("species_id", "normal_jellycat")))
	var inventory_before: int = GameState.get_inventory_count("food_basic")
	var growth_exp_before: int = int(test_pet.get("growth_exp", 0))
	var food_item: Dictionary = GameApp.get_table("items").get("food_basic", {}) as Dictionary
	var expected_food_exp: int = int(food_item.get("growth_exp_add", 0))
	var food_hunger_add: int = int(food_item.get("hunger_add", 0))
	var expected_hunger_after_feed: int = mini(int(GameApp.get_balance_value("max_hunger")), int(test_pet.get("hunger", 0)) + food_hunger_add)
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
	if token_remains or int(fed_pet.get("hunger", 0)) != expected_hunger_after_feed:
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
	_expect(int(fed_pet.get("hunger", 0)) == expected_hunger_after_feed, "%s grants the configured hunger benefit" % label)
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
	test_pet["hunger"] = int(GameApp.get_balance_value("hungry_hunger_max")) - int(GameApp.get_table("items").get("food_basic", {}).get("hunger_add", 0))
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
	var food_item: Dictionary = GameApp.get_table("items").get("food_basic", {}) as Dictionary
	var expected_food_exp: int = int(food_item.get("growth_exp_add", 0))
	var food_hunger_add: int = int(food_item.get("hunger_add", 0))
	var expected_hunger_after_feed: int = mini(int(GameApp.get_balance_value("max_hunger")), int(test_pet.get("hunger", 0)) + food_hunger_add)
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
	_expect(int(GameState.get_pet(pet_id).get("hunger", 0)) == int(test_pet.get("hunger", 0)), "A distant marker leaves hunger unchanged before contact")

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
	_expect(int(GameState.get_pet(pet_id).get("hunger", 0)) == expected_hunger_after_feed, "The remote regression feed gives the configured hunger benefit after contact")
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
	test_pet["hunger"] = int(GameApp.get_balance_value("hungry_hunger_max")) - int(GameApp.get_table("items").get("food_basic", {}).get("hunger_add", 0))
	GameState.set_pet(pet_id, test_pet)
	actor.call("refresh_pet")
	actor.call("set_stage", 1, str(test_pet.get("species_id", "normal_jellycat")))
	var water: Rect2 = aquarium.get("active_water_rect")
	var drop_position: Vector2 = water.get_center() + Vector2(160.0, 0.0)
	var inventory_before: int = GameState.get_inventory_count("food_basic")
	var growth_exp_before: int = int(test_pet.get("growth_exp", 0))
	var food_item: Dictionary = GameApp.get_table("items").get("food_basic", {}) as Dictionary
	var expected_food_exp: int = int(food_item.get("growth_exp_add", 0))
	var food_hunger_add: int = int(food_item.get("hunger_add", 0))
	var expected_hunger_after_feed: int = mini(int(GameApp.get_balance_value("max_hunger")), int(test_pet.get("hunger", 0)) + food_hunger_add)
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
	_expect(int(GameState.get_pet(pet_id).get("hunger", 0)) == expected_hunger_after_feed, "The panel-transition chase grants the configured hunger benefit")
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


func _get_nursery_fractional_pixel_layouts() -> Array[Dictionary]:
	var layouts: Array[Dictionary] = []
	var base_viewport_size: Vector2 = Vector2(1672.0, 941.0)
	var window_cases: Array[Dictionary] = [
		{"name": "1280x720", "window_size": Vector2(1280.0, 720.0)},
		{"name": "1280x591", "window_size": Vector2(1280.0, 591.0)},
		{"name": "1600x720", "window_size": Vector2(1600.0, 720.0)},
	]
	for window_case in window_cases:
		var window_size: Vector2 = window_case.get("window_size", Vector2.ZERO)
		var output_scale: float = minf(window_size.x / base_viewport_size.x, window_size.y / base_viewport_size.y)
		var expanded_viewport_size: Vector2 = window_size / output_scale
		for dpi in [160.0, 320.0]:
			layouts.append({
				"name": "%s-%ddpi-expanded-fractional" % [str(window_case.get("name", "window")), int(dpi)],
				"viewport": expanded_viewport_size,
				"safe": Rect2(Vector2.ZERO, expanded_viewport_size),
				"output_size": window_size,
				"dpi": dpi,
				"touch_target": 56.0 * dpi / (160.0 * output_scale),
				"fractional": true,
			})
	return layouts


func _test_nursery_three_card_scroll(nursery_ui: Control, source_egg: Dictionary, pixel_layouts: Array[Dictionary]) -> Dictionary:
	var probe_egg_id: String = "g1_three_card_scroll_probe"
	var probe_egg: Dictionary = source_egg.duplicate(true)
	probe_egg["egg_id"] = probe_egg_id
	probe_egg["pet_id"] = "g1_three_card_scroll_probe_pet"
	probe_egg["current_clicks"] = 0
	if not GameState.add_nursery_egg(probe_egg):
		return {"scrollable": false, "geometry_valid": false, "geometry_measurements": 0}
	var egg_scroll: ScrollContainer = nursery_ui.get("egg_scroll") as ScrollContainer
	var egg_grid: GridContainer = nursery_ui.get("egg_grid") as GridContainer
	nursery_ui.call("_refresh_cards")
	await get_tree().process_frame
	await get_tree().process_frame
	var cards: Dictionary = nursery_ui.get("egg_cards_by_id") as Dictionary
	var geometry_valid: bool = true
	var geometry_measurements: int = 0
	var integer_geometry_valid: bool = true
	var integer_geometry_measurements: int = 0
	var fractional_geometry_valid: bool = true
	var fractional_geometry_measurements: int = 0
	var third_card_scrollable: bool = true
	for pixel_case in pixel_layouts:
		var pixel_viewport: Vector2 = pixel_case["viewport"]
		var pixel_dpi: float = float(pixel_case["dpi"])
		var default_output_scale: Vector2 = Vector2(pixel_dpi / 160.0, pixel_dpi / 160.0)
		var pixel_output_size: Vector2 = pixel_case.get("output_size", pixel_viewport * default_output_scale)
		var pixel_output_scale: Vector2 = pixel_output_size / pixel_viewport
		var pixel_touch_target: float = float(pixel_case.get("touch_target", 56.0 * pixel_dpi / 160.0))
		var fractional_case: bool = bool(pixel_case.get("fractional", false))
		nursery_ui.call("_layout_ui", pixel_viewport, pixel_case["safe"], pixel_touch_target, pixel_output_size)
		for _layout_frame in range(4):
			await get_tree().process_frame
		cards = nursery_ui.get("egg_cards_by_id") as Dictionary
		var case_name: String = str(pixel_case["name"])
		var case_geometry_valid: bool = true
		var before_result: Dictionary = {"valid": false, "checks": 0}
		var after_result: Dictionary = {"valid": false, "checks": 0}
		var before_checks: int = 0
		var third_rect_before: Rect2 = Rect2()
		var third_rect_after: Rect2 = Rect2()
		var scroll_rect: Rect2 = egg_scroll.get_global_rect()
		var scroll_range: float = 0.0
		var scroll_case_valid: bool = false
		if cards.size() != 3 or egg_grid.columns != 2:
			case_geometry_valid = false
			third_card_scrollable = false
			print("G1_NURSERY_EGG_PIXEL_CASE_FAIL %s expected=3-eggs/2-columns actual=%d/%d" % [case_name, cards.size(), egg_grid.columns])
		else:
			var first_button: Button = egg_grid.get_child(0) as Button
			var second_button: Button = egg_grid.get_child(1) as Button
			var first_rect: Rect2 = first_button.get_global_rect()
			var second_rect: Rect2 = second_button.get_global_rect()
			var second_column_valid: bool = second_rect.position.x > first_rect.position.x and is_equal_approx(second_rect.position.y, first_rect.position.y)
			case_geometry_valid = case_geometry_valid and second_column_valid
			before_result = _measure_nursery_card_pixel_geometry(cards, pixel_output_scale, pixel_touch_target, case_name + ":before-scroll")
			case_geometry_valid = case_geometry_valid and bool(before_result.get("valid", false)) and second_column_valid
			before_checks = int(before_result.get("checks", 0))
			var third_button: Button = (cards.get(probe_egg_id, {}) as Dictionary).get("button") as Button
			third_rect_before = third_button.get_global_rect() if is_instance_valid(third_button) else Rect2()
			scroll_range = maxf(0.0, egg_scroll.get_v_scroll_bar().max_value - egg_scroll.get_v_scroll_bar().page)
			if scroll_range > 0.0:
				egg_scroll.scroll_vertical = ceili(scroll_range)
				for _scroll_frame in range(4):
					await get_tree().process_frame
				third_rect_after = third_button.get_global_rect()
				scroll_case_valid = third_rect_after.position.y >= scroll_rect.position.y - 1.0
				scroll_case_valid = scroll_case_valid and third_rect_after.end.y <= scroll_rect.end.y + 1.0
				scroll_case_valid = scroll_case_valid and third_rect_after.position.x >= scroll_rect.position.x
				scroll_case_valid = scroll_case_valid and third_rect_after.end.x <= scroll_rect.end.x
				scroll_case_valid = scroll_case_valid and third_rect_after.position.y < third_rect_before.position.y
				third_card_scrollable = third_card_scrollable and scroll_case_valid
				after_result = _measure_nursery_card_pixel_geometry(cards, pixel_output_scale, pixel_touch_target, case_name + ":after-scroll")
				case_geometry_valid = case_geometry_valid and scroll_case_valid and bool(after_result.get("valid", false))
			else:
				# Some 2x three-card layouts fit fully; verify their no-op post-scroll state too.
				egg_scroll.scroll_vertical = 0
				for _no_scroll_frame in range(4):
					await get_tree().process_frame
				third_rect_after = third_button.get_global_rect()
				scroll_case_valid = third_rect_before.position.y >= scroll_rect.position.y and third_rect_before.end.y <= scroll_rect.end.y
				scroll_case_valid = scroll_case_valid and third_rect_after.position.y >= scroll_rect.position.y and third_rect_after.end.y <= scroll_rect.end.y
				third_card_scrollable = third_card_scrollable and scroll_case_valid
				after_result = _measure_nursery_card_pixel_geometry(cards, pixel_output_scale, pixel_touch_target, case_name + ":no-scroll-range")
				case_geometry_valid = case_geometry_valid and scroll_case_valid and bool(after_result.get("valid", false))
		var fractional_scale_valid: bool = true
		if fractional_case:
			fractional_scale_valid = not is_equal_approx(pixel_output_scale.x, roundf(pixel_output_scale.x))
			fractional_scale_valid = fractional_scale_valid and not is_equal_approx(pixel_output_scale.y, roundf(pixel_output_scale.y))
		case_geometry_valid = case_geometry_valid and fractional_scale_valid
		case_geometry_valid = case_geometry_valid and int(before_result.get("checks", 0)) == 3 and int(after_result.get("checks", 0)) == 3
		var case_checks: int = before_checks + int(after_result.get("checks", 0))
		geometry_valid = geometry_valid and case_geometry_valid
		geometry_measurements += case_checks
		if fractional_case:
			fractional_geometry_valid = fractional_geometry_valid and case_geometry_valid
			fractional_geometry_measurements += case_checks
		else:
			integer_geometry_valid = integer_geometry_valid and case_geometry_valid
			integer_geometry_measurements += case_checks
		print("G1_NURSERY_EGG_PIXEL_CASE %s scale=%s viewport=%s columns=%d range=%.2f third_before=%s third_after=%s scroll_valid=%s result=%s" % [case_name, str(pixel_output_scale), str(pixel_viewport), egg_grid.columns, scroll_range, str(third_rect_before), str(third_rect_after), str(scroll_case_valid), str(case_geometry_valid)])
		egg_scroll.scroll_vertical = 0
		for _reset_scroll_frame in range(4):
			await get_tree().process_frame
	var probe_removed: bool = GameState.remove_nursery_egg(probe_egg_id)
	nursery_ui.call("_refresh_cards")
	for _cleanup_frame in range(4):
		await get_tree().process_frame
	return {
		"scrollable": third_card_scrollable and probe_removed,
		"geometry_valid": geometry_valid and probe_removed,
		"geometry_measurements": geometry_measurements,
		"integer_geometry_valid": integer_geometry_valid and probe_removed,
		"integer_geometry_measurements": integer_geometry_measurements,
		"fractional_geometry_valid": fractional_geometry_valid and probe_removed,
		"fractional_geometry_measurements": fractional_geometry_measurements,
		"probe_removed": probe_removed
	}


func _measure_nursery_card_pixel_geometry(cards: Dictionary, output_scale: Vector2, touch_target: float, sample_name: String) -> Dictionary:
	var valid: bool = cards.size() == 3
	var checks: int = 0
	var desired_card_width: float = maxf(256.0, touch_target * 2.25)
	var desired_card_height: float = maxf(320.0, touch_target * 2.55)
	var required_card_scale: float = maxf(desired_card_width * output_scale.x / 96.0, desired_card_height * output_scale.y / 112.0)
	var expected_card_scale: int = maxi(1, ceili(required_card_scale - 0.000001))
	var required_icon_scale: float = maxf(128.0 * output_scale.x / 64.0, 128.0 * output_scale.y / 64.0)
	var expected_icon_scale: int = maxi(1, roundi(required_icon_scale))
	for egg_id_variant in cards.keys():
		var egg_id: String = str(egg_id_variant)
		var card_data: Dictionary = cards.get(egg_id, {}) as Dictionary
		var card: Button = card_data.get("button") as Button
		var background: TextureRect = card_data.get("background") as TextureRect
		var icon: TextureRect = card_data.get("icon") as TextureRect
		var icon_slot: Control = card_data.get("icon_slot") as Control
		if not is_instance_valid(card) or not is_instance_valid(background) or not is_instance_valid(icon) or not is_instance_valid(icon_slot):
			valid = false
			continue
		checks += 1
		var card_rect: Rect2 = card.get_global_rect()
		var background_rect: Rect2 = background.get_global_rect()
		var card_source_size: Vector2 = background.texture.get_size()
		var icon_rect: Rect2 = icon.get_global_rect()
		var icon_source_size: Vector2 = icon.texture.get_size()
		var card_scale: Vector2 = Vector2(background_rect.size.x * output_scale.x / card_source_size.x, background_rect.size.y * output_scale.y / card_source_size.y)
		var icon_scale: Vector2 = Vector2(icon_rect.size.x * output_scale.x / icon_source_size.x, icon_rect.size.y * output_scale.y / icon_source_size.y)
		var card_valid: bool = _has_uniform_integer_pixel_scale(background_rect, card_source_size, output_scale)
		card_valid = card_valid and _has_integer_physical_edges(background_rect, output_scale)
		card_valid = card_valid and background_rect.position.is_equal_approx(card_rect.position) and background_rect.size.is_equal_approx(card_rect.size)
		card_valid = card_valid and card_rect.size.x >= 256.0 and card_rect.size.y >= 320.0
		card_valid = card_valid and background.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and background.stretch_mode == TextureRect.STRETCH_SCALE
		card_valid = card_valid and card_scale.is_equal_approx(Vector2(float(expected_card_scale), float(expected_card_scale)))
		var icon_transform: Transform2D = icon.get_global_transform()
		var transform_is_integer_translation: bool = icon.scale.is_equal_approx(Vector2.ONE) and absf(icon.rotation) <= 0.0001
		transform_is_integer_translation = transform_is_integer_translation and icon_transform.x.is_equal_approx(Vector2(1.0, 0.0)) and icon_transform.y.is_equal_approx(Vector2(0.0, 1.0))
		var icon_valid: bool = icon.visible and icon.size.is_equal_approx(icon.custom_minimum_size)
		icon_valid = icon_valid and icon.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and icon.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_valid = icon_valid and icon_scale.is_equal_approx(Vector2(float(expected_icon_scale), float(expected_icon_scale)))
		icon_valid = icon_valid and _has_uniform_integer_pixel_scale(icon_rect, icon_source_size, output_scale)
		icon_valid = icon_valid and _has_integer_physical_edges(icon_rect, output_scale) and transform_is_integer_translation
		var item_valid: bool = card_valid and icon_valid
		valid = valid and item_valid
		print("G1_NURSERY_EGG_PIXEL_ITEM sample=%s egg=%s card_rect=%s card_scale=%s expected_card_N=%d egg_rect=%s egg_scale=%s expected_egg_N=%d transform_integer_translation=%s result=%s" % [sample_name, egg_id, str(card_rect), str(card_scale), expected_card_scale, str(icon_rect), str(icon_scale), expected_icon_scale, str(transform_is_integer_translation), str(item_valid)])
	return {"valid": valid and checks == 3, "checks": checks}


func _has_uniform_integer_pixel_scale(art_rect: Rect2, source_size: Vector2, output_scale: Vector2) -> bool:
	if source_size.x <= 0.0 or source_size.y <= 0.0 or output_scale.x <= 0.0 or output_scale.y <= 0.0:
		return false
	var scale_x: float = art_rect.size.x * output_scale.x / source_size.x
	var scale_y: float = art_rect.size.y * output_scale.y / source_size.y
	return is_equal_approx(scale_x, roundf(scale_x)) and is_equal_approx(scale_y, roundf(scale_y)) and is_equal_approx(scale_x, scale_y)


func _has_integer_physical_edges(art_rect: Rect2, output_scale: Vector2) -> bool:
	var physical_edges: Array[float] = [
		art_rect.position.x * output_scale.x,
		art_rect.position.y * output_scale.y,
		art_rect.end.x * output_scale.x,
		art_rect.end.y * output_scale.y
	]
	for edge in physical_edges:
		if not is_equal_approx(edge, roundf(edge)):
			return false
	return true


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _run_g1_fix_26_mixed_stability_case(aquarium: Control, actor_anchor: Node2D, actors: Dictionary) -> void:
	const SIMULATION_SECONDS: float = 600.0
	const STEP_SECONDS: float = 0.1
	const OBSERVATION_SECONDS: float = 10.0
	const FOOD_ACTIVE_SECONDS: float = 8.0
	const MAX_NON_ROAM_STATE_SECONDS: float = 30.0
	const MIN_MOVEMENT_PER_WINDOW: float = 32.0
	var pet_ids: Array[String] = GameState.get_active_pet_ids()
	var saved_game_data: Dictionary = GameState.to_save_dict().duplicate(true)
	var saved_info_open: bool = bool(aquarium.get("pet_info_open"))
	var saved_passive_timer: float = float(aquarium.get("passive_timer"))
	var saved_touch_cooldown: float = float(aquarium.get("touch_cooldown"))
	var saved_actor_state: Dictionary = {}
	var simulation_now: float = Time.get_unix_time_from_system()
	var configured_touch_cooldown: float = maxf(float(GameApp.get_balance_value("touch_cooldown_seconds")), 0.0)
	var max_hunger: int = int(GameApp.get_balance_value("max_hunger"))
	var movement_by_pet: Dictionary = {}
	var stationary_refusal_by_pet: Dictionary = {}
	var max_stationary_refusal_by_pet: Dictionary = {}
	var observed_state_by_pet: Dictionary = {}
	var observed_state_seconds_by_pet: Dictionary = {}
	var all_movement_windows_valid: bool = true
	var all_refusal_animations_bounded: bool = true
	var all_non_roam_states_bounded: bool = true
	var touch_operations: int = 0
	var feed_operations: int = 0
	var panel_operations: int = 0
	var active_token: String = ""
	var active_feed_frame: int = -1
	var frame_count: int = ceili(SIMULATION_SECONDS / STEP_SECONDS)
	var observation_frames: int = ceili(OBSERVATION_SECONDS / STEP_SECONDS)
	var feed_period_frames: int = observation_frames
	var feed_lifetime_frames: int = ceili(FOOD_ACTIVE_SECONDS / STEP_SECONDS)
	var max_stationary_refusal_seconds: float = 0.0
	var max_non_roam_state_seconds: float = 0.0
	for pet_id in pet_ids:
		var actor: Node2D = actors.get(pet_id) as Node2D
		var pet: Dictionary = GameState.get_pet(pet_id)
		var care_stats: Dictionary = GameState.get_current_care_stats(pet_id)
		pet["hunger"] = max_hunger
		pet["mood"] = 0
		care_stats["last_touch_effect_at"] = simulation_now - configured_touch_cooldown - 1.0
		care_stats["touch_growth_exp_hour"] = 0
		care_stats["touch_exp_hour_started_at"] = simulation_now
		GameState.set_pet_and_care_stats(pet_id, pet, care_stats)
		if actor == null:
			continue
		saved_actor_state[pet_id] = {
			"position": actor.position,
			"roam_target": actor.get("roam_target"),
			"behavior_state": actor.get("behavior_state"),
			"food_drop_id": actor.get("food_drop_id"),
			"full_food_drop_id": actor.get("full_food_drop_id"),
			"layout_transition_active": actor.get("layout_transition_active"),
			"panel_evasion_active": actor.get("panel_evasion_active"),
			"panel_evasion_target": actor.get("panel_evasion_target"),
		}
		actor.set("food_drop_id", "")
		actor.set("full_food_drop_id", "")
		actor.set("layout_transition_active", false)
		actor.set("panel_evasion_active", false)
		actor.set("behavior_state", "idle_roam")
		movement_by_pet[pet_id] = 0.0
		stationary_refusal_by_pet[pet_id] = 0.0
		max_stationary_refusal_by_pet[pet_id] = 0.0
		observed_state_by_pet[pet_id] = "idle_roam"
		observed_state_seconds_by_pet[pet_id] = 0.0
	aquarium.set("passive_timer", -1000000.0)
	aquarium.set("touch_cooldown", 0.0)
	aquarium.call("_set_pet_info_open", false)
	print("G1_FIX26_MIXED_START simulated_seconds=600 step=0.1 pets=%s actions=food+full_refusal+touch+panel" % str(pet_ids))
	for frame_index in range(frame_count):
		var simulated_elapsed: float = float(frame_index) * STEP_SECONDS
		simulation_now = Time.get_unix_time_from_system() + simulated_elapsed
		if frame_index % feed_period_frames == 0:
			var feed_target_id: String = pet_ids[feed_operations % pet_ids.size()]
			var feed_actor: Node2D = actors.get(feed_target_id) as Node2D
			var active_water: Rect2 = aquarium.get("active_water_rect")
			var feed_position: Vector2 = feed_actor.global_position if feed_actor != null else active_water.get_center()
			var feed_drop: Dictionary = aquarium.call("_drop_basic_food", feed_position, feed_target_id)
			active_token = str(feed_drop.get("token_id", ""))
			active_feed_frame = frame_index
			feed_operations += 1
			if not active_token.is_empty():
				aquarium.call("_update_food_drops", 0.0)
			print("G1_FIX26_MIXED_ACTION t=%.1f action=feed token=%s target=%s position=%s" % [simulated_elapsed, active_token, feed_target_id, str(feed_position)])
		if frame_index % observation_frames == 0:
			for pet_id in pet_ids:
				var touch_pet: Dictionary = GameState.get_pet(pet_id)
				var care_stats: Dictionary = GameState.get_current_care_stats(pet_id)
				touch_pet["mood"] = 0
				care_stats["last_touch_effect_at"] = Time.get_unix_time_from_system() - configured_touch_cooldown - 1.0
				GameState.set_pet_and_care_stats(pet_id, touch_pet, care_stats)
				aquarium.set("touch_cooldown", 0.0)
				var touch_succeeded: bool = bool(aquarium.call("_try_touch_pet", pet_id, actors.get(pet_id) as Node2D))
				touch_operations += 1
				print("G1_FIX26_MIXED_ACTION t=%.1f action=touch pet=%s accepted=%s" % [simulated_elapsed, pet_id, str(touch_succeeded)])
			if touch_operations % 3 == 0:
				aquarium.call("_set_pet_info_open", not bool(aquarium.get("pet_info_open")))
				panel_operations += 1
				print("G1_FIX26_MIXED_ACTION t=%.1f action=toggle_pet_info open=%s" % [simulated_elapsed, str(aquarium.get("pet_info_open"))])
		aquarium.call("_process", STEP_SECONDS)
		for pet_id in pet_ids:
			var actor: Node2D = actors.get(pet_id) as Node2D
			if actor == null:
				continue
			var before_position: Vector2 = actor.position
			actor.call("_process", STEP_SECONDS)
			movement_by_pet[pet_id] = float(movement_by_pet[pet_id]) + before_position.distance_to(actor.position)
			var behavior: String = str(actor.get("behavior_state"))
			var state_seconds: float = float(observed_state_seconds_by_pet[pet_id])
			if behavior == str(observed_state_by_pet[pet_id]):
				state_seconds += STEP_SECONDS
			else:
				observed_state_by_pet[pet_id] = behavior
				state_seconds = STEP_SECONDS
			observed_state_seconds_by_pet[pet_id] = state_seconds
			if behavior != "idle_roam":
				max_non_roam_state_seconds = maxf(max_non_roam_state_seconds, state_seconds)
				all_non_roam_states_bounded = all_non_roam_states_bounded and state_seconds <= MAX_NON_ROAM_STATE_SECONDS
			var stationary_refusal: float = float(stationary_refusal_by_pet[pet_id])
			if behavior == "full_food_refusal" and before_position.distance_to(actor.position) <= 0.1:
				stationary_refusal += STEP_SECONDS
				stationary_refusal_by_pet[pet_id] = stationary_refusal
				max_stationary_refusal_by_pet[pet_id] = maxf(float(max_stationary_refusal_by_pet[pet_id]), stationary_refusal)
				max_stationary_refusal_seconds = maxf(max_stationary_refusal_seconds, stationary_refusal)
			else:
				stationary_refusal_by_pet[pet_id] = 0.0
		if not active_token.is_empty() and frame_index - active_feed_frame >= feed_lifetime_frames:
			GameState.resolve_food_drop(active_token)
			active_token = ""
			active_feed_frame = -1
			aquarium.call("_update_food_drops", 0.0)
		if (frame_index + 1) % observation_frames == 0:
			var window_end: float = float(frame_index + 1) * STEP_SECONDS
			for pet_id in pet_ids:
				var sample_actor: Node2D = actors.get(pet_id) as Node2D
				var sample_sprite: Sprite2D = sample_actor.get_node("%Sprite") as Sprite2D if sample_actor != null else null
				var distance_moved: float = float(movement_by_pet[pet_id])
				all_movement_windows_valid = all_movement_windows_valid and distance_moved >= MIN_MOVEMENT_PER_WINDOW
				var refusal_seconds: float = float(max_stationary_refusal_by_pet[pet_id])
				all_refusal_animations_bounded = all_refusal_animations_bounded and refusal_seconds <= 3.0
				print("G1_FIX26_STATE t=%.1f pet=%s behavior_state=%s roam_target=%s position=%s animation=%s rotation=%.3f moved_10s=%.2f still_refusal_max=%.1f" % [
					window_end,
					pet_id,
					str(sample_actor.get("behavior_state")) if sample_actor != null else "missing",
					str(actor_anchor.to_global(sample_actor.get("roam_target"))) if sample_actor != null else "missing",
					str(sample_actor.global_position) if sample_actor != null else "missing",
					str(sample_actor.get("behavior_state")) if sample_actor != null else "missing",
					sample_sprite.rotation if sample_sprite != null else 0.0,
					distance_moved,
					refusal_seconds,
				])
				movement_by_pet[pet_id] = 0.0
				max_stationary_refusal_by_pet[pet_id] = 0.0
			print("G1_FIX26_WINDOW t=%.1f movement_ok=%s refusal_ok=%s" % [window_end, str(all_movement_windows_valid), str(all_refusal_animations_bounded)])
	if not active_token.is_empty():
		GameState.resolve_food_drop(active_token)
		aquarium.call("_update_food_drops", 0.0)
	GameState.set_data(saved_game_data)
	SaveManager.save_game()
	aquarium.set("passive_timer", saved_passive_timer)
	aquarium.set("touch_cooldown", saved_touch_cooldown)
	for pet_id in pet_ids:
		var actor: Node2D = actors.get(pet_id) as Node2D
		var actor_snapshot: Dictionary = saved_actor_state.get(pet_id, {}) as Dictionary
		if actor == null or actor_snapshot.is_empty():
			continue
		actor.position = actor_snapshot.get("position", actor.position)
		actor.set("roam_target", actor_snapshot.get("roam_target", actor.get("roam_target")))
		actor.set("behavior_state", actor_snapshot.get("behavior_state", "idle_roam"))
		actor.set("food_drop_id", actor_snapshot.get("food_drop_id", ""))
		actor.set("full_food_drop_id", actor_snapshot.get("full_food_drop_id", ""))
		actor.set("layout_transition_active", actor_snapshot.get("layout_transition_active", false))
		actor.set("panel_evasion_active", actor_snapshot.get("panel_evasion_active", false))
		actor.set("panel_evasion_target", actor_snapshot.get("panel_evasion_target", actor.position))
	aquarium.call("_set_pet_info_open", saved_info_open)
	aquarium.call("_refresh", false)
	_expect(feed_operations == 60 and touch_operations == 180 and panel_operations == 60, "Ten simulated minutes execute 60 feed drops, 180 repeated touches, and 60 information-panel toggles")
	_expect(all_movement_windows_valid, "Every pet swims at least 32 units during every 10-second mixed-operation window")
	_expect(all_refusal_animations_bounded, "No pet shakes in place for longer than three seconds during the ten-minute mixed-operation run")
	_expect(all_non_roam_states_bounded, "Every non-roaming behavior state remains bounded to 30 seconds or less")
	print("G1_FIX26_MIXED_RESULT simulated_seconds=600 feeds=%d touches=%d panel_toggles=%d max_non_roam_state=%.1f max_stationary_refusal=%.1f movement_windows_ok=%s refusal_windows_ok=%s state_bounds_ok=%s" % [
		feed_operations,
		touch_operations,
		panel_operations,
		max_non_roam_state_seconds,
		max_stationary_refusal_seconds,
		str(all_movement_windows_valid),
		str(all_refusal_animations_bounded),
		str(all_non_roam_states_bounded),
	])


func _coin_drop_is_pending(token_id: String) -> bool:
	if token_id.is_empty():
		return false
	for coin_drop in GameState.get_coin_drops():
		if str(coin_drop.get("token_id", "")) == token_id:
			return true
	return false


func _finish() -> void:
	if failures.is_empty():
		print("G1_GAMEPLAY_ACCEPTANCE_OK checks=%d" % checks)
		get_tree().quit(0)
		return
	for failure in failures:
		push_error("G1_GAMEPLAY_ACCEPTANCE_FAIL: %s" % failure)
	print("G1_GAMEPLAY_ACCEPTANCE_FAILED checks=%d failures=%d" % [checks, failures.size()])
	get_tree().quit(1)