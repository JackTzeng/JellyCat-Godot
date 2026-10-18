extends Control

const DOS_STYLE = preload("res://scripts/ui/dos_style.gd")
const NATIVE_TEXT_ENTRY = preload("res://scripts/ui/native_text_entry.gd")
const EGG_IDLE: Texture2D = preload("res://assets/eggs/egg_idle_v2_64.png")
const EGG_CRACK_1: Texture2D = preload("res://assets/eggs/egg_crack1_v2_64.png")
const EGG_CRACK_2: Texture2D = preload("res://assets/eggs/egg_crack2_v2_64.png")
const EGG_CRACK_3: Texture2D = preload("res://assets/eggs/egg_crack3_v2_64.png")
const EGG_BURST: Texture2D = preload("res://assets/eggs/egg_hatch_burst_v2_64.png")
const EGG_WOBBLE: Texture2D = preload("res://assets/eggs/egg_wobble_sheet_v2_3x64.png")
const CARD_BACKGROUND: Texture2D = preload("res://assets/nursery/nursery_card_bg_96x112.png")
const EMPTY_SLOT: Texture2D = preload("res://assets/nursery/nursery_slot_empty_96x112.png")
const AQUARIUM_SCENE: String = "res://scenes/aquarium/aquarium.tscn"
const EGG_REQUIRED_CLICK_FALLBACK: int = 10
const CARD_MIN_WIDTH: float = 256.0
const CARD_MIN_HEIGHT: float = 320.0
const EGG_ART_BASE_SIZE: Vector2 = Vector2(128.0, 128.0)
const NAME_MAX_LENGTH: int = 18

var title_label: Label
var subtitle_label: Label
var egg_count_label: Label
var back_button: Button
var egg_scroll: ScrollContainer
var egg_grid: GridContainer
var name_overlay: ColorRect
var name_panel: PanelContainer
var name_edit: LineEdit
var name_error_label: Label
var name_confirm_button: Button
var name_cancel_button: Button
var route_timer: Timer
var egg_cards_by_id: Dictionary = {}
var wobble_tweens: Dictionary = {}
var hatch_locked: bool = false
var hatch_committed: bool = false
var hatch_egg_id: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	get_tree().quit_on_go_back = false
	_build_ui()
	DOS_STYLE.apply(self)
	_apply_card_styles()
	_ensure_active_egg()
	_refresh_cards()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	get_window().go_back_requested.connect(_on_android_go_back_requested)
	_apply_responsive_layout()
	_resume_ready_egg()


func _exit_tree() -> void:
	if get_tree() != null:
		get_tree().quit_on_go_back = true


func _build_ui() -> void:
	var background: ColorRect = ColorRect.new()
	background.name = "Background"
	background.color = Color("#07131a")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "育嬰室"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.add_theme_font_size_override("font_size", 30)
	add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.name = "SubtitleLabel"
	subtitle_label.text = "點擊蛋卡推進孵化；每顆蛋的進度各自保存。"
	subtitle_label.add_theme_color_override("font_color", DOS_STYLE.MUTED_COLOR)
	add_child(subtitle_label)

	egg_count_label = Label.new()
	egg_count_label.name = "EggCountLabel"
	egg_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	egg_count_label.add_theme_color_override("font_color", DOS_STYLE.ACCENT_COLOR)
	add_child(egg_count_label)

	back_button = Button.new()
	back_button.name = "BackToAquariumButton"
	back_button.text = "返回水族箱"
	back_button.pressed.connect(_on_back_button_pressed)
	add_child(back_button)

	egg_scroll = ScrollContainer.new()
	egg_scroll.name = "EggScroll"
	egg_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(egg_scroll)

	var grid_center: CenterContainer = CenterContainer.new()
	grid_center.name = "EggGridCenter"
	grid_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	egg_scroll.add_child(grid_center)

	egg_grid = GridContainer.new()
	egg_grid.name = "EggGrid"
	egg_grid.add_theme_constant_override("h_separation", 16)
	egg_grid.add_theme_constant_override("v_separation", 16)
	grid_center.add_child(egg_grid)

	name_overlay = ColorRect.new()
	name_overlay.name = "NameOverlay"
	name_overlay.color = Color(0.0, 0.0, 0.0, 0.76)
	name_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	name_overlay.visible = false
	name_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(name_overlay)

	name_panel = PanelContainer.new()
	name_panel.name = "NamePanel"
	name_panel.visible = false
	add_child(name_panel)

	var name_contents: VBoxContainer = VBoxContainer.new()
	name_contents.name = "NameContents"
	name_contents.add_theme_constant_override("separation", 12)
	name_panel.add_child(name_contents)

	var name_title: Label = Label.new()
	name_title.text = "新朋友要叫什麼名字？"
	name_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_title.add_theme_font_size_override("font_size", 24)
	name_contents.add_child(name_title)

	var name_hint: Label = Label.new()
	name_hint.text = "最多 %d 個字，可使用中文。" % NAME_MAX_LENGTH
	name_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_hint.add_theme_color_override("font_color", DOS_STYLE.MUTED_COLOR)
	name_contents.add_child(name_hint)

	name_edit = LineEdit.new()
	name_edit.name = "PetNicknameEdit"
	name_edit.placeholder_text = "輸入水母喵名字"
	name_edit.max_length = NAME_MAX_LENGTH
	name_edit.virtual_keyboard_enabled = true
	name_edit.gui_input.connect(_on_name_edit_gui_input)
	name_edit.text_submitted.connect(_on_name_confirmed)
	name_contents.add_child(name_edit)

	name_error_label = Label.new()
	name_error_label.name = "NameErrorLabel"
	name_error_label.text = ""
	name_error_label.visible = false
	name_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_error_label.add_theme_color_override("font_color", Color("#ff9b8e"))
	name_contents.add_child(name_error_label)

	var name_actions: HBoxContainer = HBoxContainer.new()
	name_actions.name = "NameActions"
	name_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	name_actions.add_theme_constant_override("separation", 12)
	name_contents.add_child(name_actions)

	name_confirm_button = Button.new()
	name_confirm_button.name = "NameConfirmButton"
	name_confirm_button.text = "完成孵化"
	name_confirm_button.pressed.connect(_on_name_confirmed.bind(""))
	name_actions.add_child(name_confirm_button)

	name_cancel_button = Button.new()
	name_cancel_button.name = "NameCancelButton"
	name_cancel_button.text = "稍後再說"
	name_cancel_button.pressed.connect(_on_name_cancelled)
	name_actions.add_child(name_cancel_button)


func _apply_card_styles() -> void:
	for card_data in egg_cards_by_id.values():
		var card: Button = (card_data as Dictionary).get("button") as Button
		_apply_card_style(card)


func _apply_card_style(card: Button) -> void:
	if card == null:
		return
	DOS_STYLE.style_button(card)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_content_margin_all(12.0)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		card.add_theme_stylebox_override(state, style)


func _ensure_active_egg() -> void:
	var eggs: Array[Dictionary] = GameState.get_nursery_eggs()
	if eggs.is_empty():
		return
	if GameState.get_nursery_egg(GameState.get_active_egg_id()).is_empty():
		GameState.set_active_egg_id(str(eggs[0].get("egg_id", "")))
		SaveManager.save_game()


func _refresh_cards() -> void:
	var eggs: Array[Dictionary] = GameState.get_nursery_eggs()
	egg_count_label.text = "%d 顆待孵化" % eggs.size()
	var cards_match: bool = egg_cards_by_id.size() == eggs.size()
	if cards_match:
		for egg in eggs:
			if not egg_cards_by_id.has(str(egg.get("egg_id", ""))):
				cards_match = false
				break
	if cards_match:
		for egg in eggs:
			_render_egg_card(egg)
		_sync_card_interaction()
		return
	for child in egg_grid.get_children():
		child.queue_free()
	egg_cards_by_id.clear()
	if eggs.is_empty():
		var empty_content: VBoxContainer = VBoxContainer.new()
		empty_content.name = "EmptyNurserySlot"
		empty_content.alignment = BoxContainer.ALIGNMENT_CENTER
		empty_content.add_theme_constant_override("separation", 8)
		empty_content.custom_minimum_size = Vector2(220.0, 260.0)
		var empty_icon: TextureRect = TextureRect.new()
		empty_icon.name = "EmptySlotArtwork"
		empty_icon.texture = EMPTY_SLOT
		empty_icon.custom_minimum_size = Vector2(192.0, 224.0)
		empty_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		empty_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		empty_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		empty_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		empty_content.add_child(empty_icon)
		var empty_label: Label = Label.new()
		empty_label.text = "所有蛋都已孵化"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		empty_content.add_child(empty_label)
		egg_grid.add_child(empty_content)
		return

	for egg in eggs:
		var egg_id: String = str(egg.get("egg_id", ""))
		if egg_id.is_empty():
			continue
		var card: Button = Button.new()
		card.name = "EggCard_%s" % egg_id
		card.custom_minimum_size = Vector2(CARD_MIN_WIDTH, CARD_MIN_HEIGHT)
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		card.pressed.connect(_on_egg_card_pressed.bind(egg_id))
		egg_grid.add_child(card)
		_apply_card_style(card)

		var background: TextureRect = TextureRect.new()
		background.name = "CardArtwork"
		background.texture = CARD_BACKGROUND
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_SCALE
		background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card.add_child(background)

		var content: VBoxContainer = VBoxContainer.new()
		content.name = "EggCardContent"
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 12.0
		content.offset_top = 16.0
		content.offset_right = -12.0
		content.offset_bottom = -12.0
		content.alignment = BoxContainer.ALIGNMENT_BEGIN
		content.add_theme_constant_override("separation", 6)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(content)

		var active_label: Label = Label.new()
		active_label.name = "ActiveEggLabel"
		active_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		active_label.add_theme_font_size_override("font_size", 16)
		active_label.add_theme_color_override("font_color", DOS_STYLE.ACCENT_COLOR)
		active_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(active_label)

		var egg_icon: TextureRect = TextureRect.new()
		egg_icon.name = "EggArtwork"
		egg_icon.custom_minimum_size = Vector2(128.0, 128.0)
		egg_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		egg_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		egg_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		egg_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		egg_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		egg_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(egg_icon)

		var progress_label: Label = Label.new()
		progress_label.name = "EggProgressLabel"
		progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		progress_label.add_theme_font_size_override("font_size", 16)
		progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(progress_label)

		var hint_label: Label = Label.new()
		hint_label.name = "EggHintLabel"
		hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_label.add_theme_font_size_override("font_size", 14)
		hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(hint_label)

		egg_cards_by_id[egg_id] = {
			"button": card,
			"background": background,
			"active": active_label,
			"icon": egg_icon,
			"progress": progress_label,
			"hint": hint_label
		}
		_render_egg_card(egg)
	_sync_card_interaction()


func _render_egg_card(egg: Dictionary) -> void:
	var egg_id: String = str(egg.get("egg_id", ""))
	if not egg_cards_by_id.has(egg_id):
		return
	var card_data: Dictionary = egg_cards_by_id[egg_id] as Dictionary
	var current_clicks: int = maxi(0, int(egg.get("current_clicks", 0)))
	var required_clicks: int = maxi(1, int(egg.get("required_clicks", EGG_REQUIRED_CLICK_FALLBACK)))
	var icon: TextureRect = card_data.get("icon") as TextureRect
	icon.texture = _get_egg_progress_texture(current_clicks, required_clicks)
	(card_data.get("progress") as Label).text = "孵化進度  %d / %d" % [mini(current_clicks, required_clicks), required_clicks]
	(card_data.get("active") as Label).text = "▶ 目前孵化" if egg_id == GameState.get_active_egg_id() else "　"
	var hint: Label = card_data.get("hint") as Label
	hint.text = "蛋殼已完成，請為新朋友命名。" if current_clicks >= required_clicks else "點擊蛋殼，繼續孵化。"
	if current_clicks >= required_clicks:
		hint.add_theme_color_override("font_color", DOS_STYLE.ACCENT_COLOR)
	else:
		hint.add_theme_color_override("font_color", DOS_STYLE.MUTED_COLOR)


func _get_egg_progress_texture(current_clicks: int, required_clicks: int) -> Texture2D:
	if current_clicks >= required_clicks:
		return EGG_BURST
	if current_clicks <= 0:
		return EGG_IDLE
	var crack_stage: int = clampi(ceili(float(current_clicks) * 3.0 / float(required_clicks)), 1, 3)
	match crack_stage:
		1:
			return EGG_CRACK_1
		2:
			return EGG_CRACK_2
		_:
			return EGG_CRACK_3


func _play_wobble_animation(egg_id: String) -> void:
	var old_tween: Tween = wobble_tweens.get(egg_id) as Tween
	if is_instance_valid(old_tween):
		old_tween.kill()
	var tween: Tween = create_tween()
	wobble_tweens[egg_id] = tween
	for frame_index in range(3):
		tween.tween_callback(_set_wobble_frame.bind(egg_id, frame_index))
		tween.tween_interval(0.07)
	tween.tween_callback(_restore_egg_progress_frame.bind(egg_id))


func _set_wobble_frame(egg_id: String, frame_index: int) -> void:
	if not egg_cards_by_id.has(egg_id):
		return
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = EGG_WOBBLE
	atlas.region = Rect2(float(frame_index * 64), 0.0, 64.0, 64.0)
	atlas.filter_clip = true
	((egg_cards_by_id[egg_id] as Dictionary).get("icon") as TextureRect).texture = atlas


func _restore_egg_progress_frame(egg_id: String) -> void:
	var egg: Dictionary = GameState.get_nursery_egg(egg_id)
	if not egg.is_empty():
		_render_egg_card(egg)
	wobble_tweens.erase(egg_id)


func _on_egg_card_pressed(egg_id: String) -> void:
	if hatch_locked:
		return
	var egg: Dictionary = GameState.get_nursery_egg(egg_id)
	if egg.is_empty():
		_refresh_cards()
		return
	if GameState.get_active_egg_id() != egg_id:
		GameState.set_active_egg_id(egg_id)
	var current_clicks: int = int(egg.get("current_clicks", 0))
	var required_clicks: int = maxi(1, int(egg.get("required_clicks", EGG_REQUIRED_CLICK_FALLBACK)))
	if current_clicks >= required_clicks:
		_begin_hatch(egg_id, false)
		return
	var updated_egg: Dictionary = HatchSystem.advance_egg_progress(egg_id)
	if updated_egg.is_empty():
		return
	SaveManager.save_game()
	_refresh_cards()
	if int(updated_egg.get("current_clicks", 0)) >= required_clicks:
		_begin_hatch(egg_id, true)
	else:
		_play_wobble_animation(egg_id)


func _begin_hatch(egg_id: String, play_burst: bool) -> void:
	if hatch_locked:
		return
	var egg: Dictionary = GameState.get_nursery_egg(egg_id)
	if egg.is_empty() or int(egg.get("current_clicks", 0)) < int(egg.get("required_clicks", EGG_REQUIRED_CLICK_FALLBACK)):
		return
	hatch_locked = true
	hatch_egg_id = egg_id
	_sync_card_interaction()
	if play_burst:
		_render_egg_card(egg)
		var card_data: Dictionary = egg_cards_by_id.get(egg_id, {}) as Dictionary
		var icon: TextureRect = card_data.get("icon") as TextureRect
		if is_instance_valid(icon):
			icon.pivot_offset = icon.size * 0.5
			var tween: Tween = create_tween()
			tween.tween_property(icon, "scale", Vector2(1.12, 1.12), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(icon, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await get_tree().create_timer(0.36).timeout
	if not is_inside_tree():
		return
	_open_naming_panel()


func _resume_ready_egg() -> void:
	for egg in GameState.get_nursery_eggs():
		if int(egg.get("current_clicks", 0)) >= int(egg.get("required_clicks", EGG_REQUIRED_CLICK_FALLBACK)):
			_begin_hatch(str(egg.get("egg_id", "")), false)
			return


func _open_naming_panel() -> void:
	name_error_label.visible = false
	name_error_label.text = ""
	name_edit.text = ""
	name_overlay.visible = true
	name_panel.visible = true
	_sync_card_interaction()
	_apply_responsive_layout()
	name_edit.call_deferred("grab_focus")
	NATIVE_TEXT_ENTRY.open_keyboard(name_edit, "nursery_name")


func _on_name_edit_gui_input(event: InputEvent) -> void:
	NATIVE_TEXT_ENTRY.handle_gui_input(event, name_edit, "nursery_name")


func _on_name_confirmed(_submitted_text: String = "") -> void:
	if not hatch_locked or hatch_committed:
		return
	var nickname: String = name_edit.text.strip_edges()
	if nickname.is_empty():
		name_error_label.text = "請輸入名字，或稍後再為牠命名。"
		name_error_label.visible = true
		return
	if GameState.get_nursery_egg(hatch_egg_id).is_empty():
		name_error_label.text = "這顆蛋已不在育嬰室中。"
		name_error_label.visible = true
		return
	hatch_committed = true
	var pet: Dictionary = HatchSystem.create_pet_from_egg(hatch_egg_id, nickname)
	if pet.is_empty():
		hatch_committed = false
		name_error_label.text = "孵化暫時無法完成，請再試一次。"
		name_error_label.visible = true
		return
	GameState.set_selected_pet_id(str(pet.get("pet_id", "")))
	SaveManager.save_game()
	name_overlay.visible = false
	name_panel.visible = false
	_refresh_cards()
	status_label_placeholder()
	route_timer = Timer.new()
	route_timer.name = "ReturnToAquariumTimer"
	route_timer.one_shot = true
	route_timer.wait_time = 0.45
	route_timer.timeout.connect(_route_to_aquarium)
	add_child(route_timer)
	route_timer.start()


func status_label_placeholder() -> void:
	subtitle_label.text = "新朋友「%s」已加入水族箱。" % str(GameState.get_pet(GameState.get_selected_pet_id()).get("nickname", ""))


func _on_name_cancelled() -> void:
	name_overlay.visible = false
	name_panel.visible = false
	hatch_locked = false
	hatch_committed = false
	hatch_egg_id = ""
	_sync_card_interaction()
	_return_to_aquarium()


func _on_back_button_pressed() -> void:
	_return_to_aquarium()


func _on_android_go_back_requested() -> void:
	_return_to_aquarium()


func _return_to_aquarium() -> void:
	if is_instance_valid(route_timer):
		route_timer.stop()
	if is_instance_valid(name_edit) and name_edit.has_focus():
		name_edit.release_focus()
	name_overlay.visible = false
	name_panel.visible = false
	SaveManager.save_game()
	SceneRouter.go_to(AQUARIUM_SCENE)


func _route_to_aquarium() -> void:
	if is_instance_valid(route_timer):
		route_timer.stop()
	SceneRouter.go_to(AQUARIUM_SCENE)


func _sync_card_interaction() -> void:
	for card_data in egg_cards_by_id.values():
		var card: Button = (card_data as Dictionary).get("button") as Button
		if is_instance_valid(card):
			card.disabled = hatch_locked


func _apply_responsive_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280.0, 720.0)
	var safe_rect: Rect2 = _get_safe_viewport_rect(viewport_size)
	_layout_ui(viewport_size, safe_rect)


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


func _layout_ui(viewport_size: Vector2, safe_rect: Rect2, touch_target_override: float = -1.0, output_size_override: Vector2 = Vector2.ZERO) -> void:
	var safe_left: float = maxf(0.0, safe_rect.position.x)
	var safe_top: float = maxf(0.0, safe_rect.position.y)
	var safe_right: float = minf(viewport_size.x, safe_rect.position.x + safe_rect.size.x)
	var safe_bottom: float = minf(viewport_size.y, safe_rect.position.y + safe_rect.size.y)
	var safe_width: float = maxf(1.0, safe_right - safe_left)
	var safe_height: float = maxf(1.0, safe_bottom - safe_top)
	var touch_target: float = touch_target_override if touch_target_override > 0.0 else DOS_STYLE.get_touch_target_height(viewport_size)
	var output_size: Vector2 = output_size_override
	if output_size.x <= 0.0 or output_size.y <= 0.0:
		output_size = Vector2(DisplayServer.window_get_size())
		if output_size.x <= 0.0 or output_size.y <= 0.0:
			output_size = Vector2(DisplayServer.screen_get_size())
	var output_scale: Vector2 = Vector2(output_size.x / viewport_size.x, output_size.y / viewport_size.y)
	var margin: float = clampf(touch_target * 0.15, 12.0, 24.0)
	var back_width: float = minf(maxf(152.0, touch_target * 1.8), maxf(112.0, safe_width * 0.42))
	var header_y: float = safe_top + margin
	var back_rect: Rect2 = Rect2(Vector2(safe_right - margin - back_width, header_y), Vector2(back_width, touch_target))
	_place_control(back_button, back_rect)
	var title_width: float = maxf(1.0, safe_width - back_width - margin * 3.0)
	_place_control(title_label, Rect2(Vector2(safe_left + margin, header_y), Vector2(title_width, 40.0)))
	_place_control(subtitle_label, Rect2(Vector2(safe_left + margin, header_y + 42.0), Vector2(title_width, 36.0)))
	_place_control(egg_count_label, Rect2(Vector2(safe_left + margin, header_y + 76.0), Vector2(title_width, 28.0)))
	var scroll_top: float = header_y + maxf(touch_target, 108.0) + margin
	var scroll_bottom: float = safe_bottom - margin
	var scroll_left: float = safe_left + margin
	var card_width: float = maxf(CARD_MIN_WIDTH, touch_target * 2.25)
	var columns: int = 2 if safe_width >= card_width * 2.0 + 56.0 else 1
	egg_grid.columns = columns
	var desired_card_size: Vector2 = Vector2(card_width, maxf(CARD_MIN_HEIGHT, touch_target * 2.55))
	var pixel_card_size: Vector2 = _integer_pixel_art_size(Vector2(CARD_BACKGROUND.get_size()), desired_card_size, output_scale, true)
	for card_data in egg_cards_by_id.values():
		var card: Button = (card_data as Dictionary).get("button") as Button
		var icon: TextureRect = (card_data as Dictionary).get("icon") as TextureRect
		card.custom_minimum_size = pixel_card_size
		icon.custom_minimum_size = _integer_pixel_art_size(Vector2(icon.texture.get_size()), EGG_ART_BASE_SIZE, output_scale)
		icon.pivot_offset = icon.size * 0.5
	var aligned_scroll_top: float = scroll_top
	var aligned_scroll_left: float = scroll_left
	var aligned_scroll_height: float = maxf(1.0, scroll_bottom - scroll_top)
	if output_scale.x > 0.0:
		aligned_scroll_left = roundf(scroll_left * output_scale.x) / output_scale.x
	if output_scale.y > 0.0:
		aligned_scroll_top = roundf(scroll_top * output_scale.y) / output_scale.y
		aligned_scroll_height = maxf(1.0, scroll_bottom - aligned_scroll_top)
		if not egg_cards_by_id.is_empty():
			var grid_rows: int = ceili(float(egg_cards_by_id.size()) / float(columns))
			var grid_height: float = pixel_card_size.y * float(grid_rows)
			grid_height += float(egg_grid.get_theme_constant("v_separation")) * float(maxi(0, grid_rows - 1))
			var free_physical_height: float = aligned_scroll_height * output_scale.y - grid_height * output_scale.y
			if free_physical_height >= 0.0:
				var centered_free_physical_height: float = floorf(free_physical_height * 0.5) * 2.0
				aligned_scroll_height = (grid_height * output_scale.y + centered_free_physical_height) / output_scale.y
	_place_control(egg_scroll, Rect2(Vector2(aligned_scroll_left, aligned_scroll_top), Vector2(maxf(1.0, safe_width - margin * 2.0), aligned_scroll_height)))
	var panel_width: float = minf(520.0, maxf(1.0, safe_width - margin * 2.0))
	name_edit.custom_minimum_size.x = maxf(112.0, panel_width - 48.0)
	var panel_height: float = minf(maxf(200.0, name_panel.get_combined_minimum_size().y), maxf(1.0, safe_height - margin * 2.0))
	_place_control(name_panel, Rect2(Vector2(safe_left + (safe_width - panel_width) * 0.5, safe_top + (safe_height - panel_height) * 0.5), Vector2(panel_width, panel_height)))


func _place_control(control: Control, target_rect: Rect2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = target_rect.position
	control.size = target_rect.size


func _integer_pixel_art_size(source_size: Vector2, desired_size: Vector2, output_scale: Vector2, round_up: bool = false) -> Vector2:
	if source_size.x <= 0.0 or source_size.y <= 0.0 or output_scale.x <= 0.0 or output_scale.y <= 0.0:
		return desired_size
	var required_scale: float = maxf(desired_size.x * output_scale.x / source_size.x, desired_size.y * output_scale.y / source_size.y)
	var integer_scale: int = maxi(1, ceili(required_scale - 0.000001) if round_up else roundi(required_scale))
	return Vector2(source_size.x * float(integer_scale) / output_scale.x, source_size.y * float(integer_scale) / output_scale.y)
