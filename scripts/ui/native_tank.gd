extends Control
## Visual backdrop only. Does not own water bounds, actors, input, or facilities.

const BACKGROUND_TEXTURE: Texture2D = preload("res://assets/background/tank_16x9.png")
const CENTER_TILE_TEXTURE: Texture2D = preload("res://assets/background/tank_center_tile_32x180.png")

const BACKGROUND_SIZE: Vector2 = Vector2(640.0, 360.0)

@export_range(1, 16, 1) var visual_unit: int = 2:
	set(value):
		visual_unit = clampi(value, 1, 16)
		queue_redraw()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var integer_scale: int = maxi(1, roundi(size.y / BACKGROUND_SIZE.y))
	var logical_size: Vector2 = size / float(integer_scale)
	var background_origin: Vector2 = Vector2(
		(logical_size.x - BACKGROUND_SIZE.x) * 0.5,
		(logical_size.y - BACKGROUND_SIZE.y) * 0.5
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * float(integer_scale))
	var tile_display_scale: float = BACKGROUND_SIZE.y / float(CENTER_TILE_TEXTURE.get_height())
	var tile_display_size: Vector2 = Vector2(CENTER_TILE_TEXTURE.get_size()) * tile_display_scale
	if background_origin.x > 0.0:
		_draw_horizontal_extension(0.0, background_origin.x, background_origin.y, tile_display_size)
		_draw_horizontal_extension(background_origin.x + BACKGROUND_SIZE.x, background_origin.x, background_origin.y, tile_display_size)
	draw_texture_rect(BACKGROUND_TEXTURE, Rect2(background_origin, BACKGROUND_SIZE), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_horizontal_extension(start_x: float, width: float, top_y: float, tile_size: Vector2) -> void:
	var right_edge: float = start_x + width
	var tile_x: float = start_x
	while tile_x < right_edge:
		draw_texture_rect(CENTER_TILE_TEXTURE, Rect2(Vector2(tile_x, top_y), tile_size), false)
		tile_x += tile_size.x

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
