extends RefCounted


static func open_keyboard(line_edit: LineEdit, field_name: String) -> void:
	if not is_instance_valid(line_edit) or not line_edit.is_inside_tree():
		return
	line_edit.virtual_keyboard_enabled = true
	line_edit.grab_focus()
	var request_time_msec: int = Time.get_ticks_msec()
	RuntimeLogger.log_info("IME keyboard request field=%s time_msec=%d" % [field_name, request_time_msec])
	var observation_timer: SceneTreeTimer = line_edit.get_tree().create_timer(0.5)
	observation_timer.timeout.connect(func() -> void:
		if not is_instance_valid(line_edit):
			return
		var sample_time_msec: int = Time.get_ticks_msec()
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
			var keyboard_height: int = DisplayServer.virtual_keyboard_get_height()
			RuntimeLogger.log_info("IME keyboard height field=%s request_msec=%d sample_msec=%d height=%d" % [field_name, request_time_msec, sample_time_msec, keyboard_height])
		else:
			RuntimeLogger.log_info("IME keyboard height field=%s request_msec=%d sample_msec=%d height=unsupported display_server=%s" % [field_name, request_time_msec, sample_time_msec, DisplayServer.get_name()])
	)
	if OS.get_name() == "Android":
		DisplayServer.virtual_keyboard_show(line_edit.text, Rect2i(line_edit.get_global_rect()))


static func handle_gui_input(event: InputEvent, line_edit: LineEdit, field_name: String) -> void:
	var pressed: bool = false
	if event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		pressed = mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	if pressed:
		open_keyboard(line_edit, field_name)
