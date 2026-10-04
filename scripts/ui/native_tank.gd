extends Control
## Visual backdrop only. Does not own water bounds, actors, input, or facilities.

@export_range(1, 16, 1) var visual_unit: int = 2:
	set(value):
		visual_unit = clampi(value, 1, 16)
		queue_redraw()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var u := float(visual_unit)
	draw_rect(Rect2(Vector2.ZERO, size), Color("14182E"))
	if size.x < 16*u or size.y < 16*u:
		return
	var water := Rect2(Vector2(u, u), (size/u).floor()*u-Vector2.ONE*2*u)
	draw_rect(water, Color("345C79"))
	var band_height := floorf(water.size.y / (4*u))*u
	draw_rect(Rect2(water.position, Vector2(water.size.x, band_height)), Color("4A8191"))
	var sand_y := water.end.y-4*u
	draw_rect(Rect2(Vector2(water.position.x, sand_y), Vector2(water.size.x, 4*u)), Color("526078"))
	for x in range(1, int(water.end.x/u)-3, 4):
		var rise := u if (x/4) % 2 == 0 else 2*u
		draw_rect(Rect2(Vector2(x*u, sand_y-rise), Vector2(3*u, rise)), Color("8590A2"))
		draw_rect(Rect2(Vector2(x*u, sand_y), Vector2(u, u)), Color("79B3B0"))

static func make_panel(visual_unit: int = 1) -> StyleBoxFlat:
	assert(visual_unit >= 1)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("263653")
	panel.border_color = Color("14182E")
	panel.set_border_width_all(visual_unit)
	panel.anti_aliasing = false
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		panel.set_content_margin(side, 4*visual_unit)
	return panel
