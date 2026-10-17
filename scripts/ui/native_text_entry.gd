extends RefCounted


static func open_keyboard(line_edit: LineEdit) -> void:
	if not is_instance_valid(line_edit) or not line_edit.is_inside_tree():
		return
	line_edit.virtual_keyboard_enabled = true
	line_edit.grab_focus()
	if OS.get_name() == "Android":
		DisplayServer.virtual_keyboard_show(line_edit.text, Rect2i(line_edit.get_global_rect()))


static func handle_gui_input(event: InputEvent, line_edit: LineEdit) -> void:
	var pressed: bool = false
	if event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		pressed = mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	if pressed:
		open_keyboard(line_edit)
