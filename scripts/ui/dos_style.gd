extends RefCounted

const TEXT_COLOR: Color = Color("#d9f1f2")
const MUTED_COLOR: Color = Color("#8cb3bd")
const PANEL_COLOR: Color = Color("#071923")
const BUTTON_COLOR: Color = Color("#123643")
const HIGHLIGHT_COLOR: Color = Color("#22596a")
const ACCENT_COLOR: Color = Color("#f0d67a")


static func apply(root: Control) -> void:
	if root == null:
		return
	var touch_target: float = get_touch_target_height(root.get_viewport_rect().size)
	root.add_theme_color_override("font_color", TEXT_COLOR)
	for control in root.find_children("*", "Control", true, false):
		(control as Control).add_theme_color_override("font_color", TEXT_COLOR)
	for button_node in root.find_children("*", "Button", true, false):
		var button: Button = button_node as Button
		_style_button(button, touch_target)
	for panel_node in root.find_children("*", "PanelContainer", true, false):
		var panel: StyleBoxFlat = StyleBoxFlat.new()
		panel.bg_color = PANEL_COLOR
		panel.border_color = HIGHLIGHT_COLOR
		panel.set_border_width_all(2)
		panel.set_corner_radius_all(0)
		(panel_node as PanelContainer).add_theme_stylebox_override("panel", panel)


static func style_button(button: Button) -> void:
	if button != null:
		_style_button(button, get_touch_target_height(button.get_viewport_rect().size))


static func get_touch_target_height(viewport_size: Vector2) -> float:
	if DisplayServer.get_name() != "Android":
		return 56.0
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	var dpi: int = DisplayServer.screen_get_dpi()
	if screen_size.y <= 0 or dpi <= 0 or viewport_size.y <= 0.0:
		return 56.0
	var physical_pixels: float = 56.0 * float(dpi) / 160.0
	var viewport_scale: float = viewport_size.y / float(screen_size.y)
	return physical_pixels * viewport_scale


static func _style_button(button: Button, touch_target: float) -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", _button_style(BUTTON_COLOR, HIGHLIGHT_COLOR))
	button.add_theme_stylebox_override("hover", _button_style(HIGHLIGHT_COLOR, ACCENT_COLOR))
	button.add_theme_stylebox_override("pressed", _button_style(Color("#08141c"), ACCENT_COLOR))
	button.add_theme_stylebox_override("focus", _button_style(BUTTON_COLOR, ACCENT_COLOR))
	button.add_theme_stylebox_override("disabled", _button_style(PANEL_COLOR, Color("#29434a")))
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", ACCENT_COLOR)
	button.add_theme_color_override("font_disabled_color", MUTED_COLOR)
	button.add_theme_color_override("font_focus_color", TEXT_COLOR)
	button.custom_minimum_size.x = maxf(button.custom_minimum_size.x, touch_target)
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, touch_target)


static func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style
