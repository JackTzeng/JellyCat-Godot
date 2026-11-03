extends Button

const DOS_STYLE = preload("res://scripts/ui/dos_style.gd")

@onready var idle_art: TextureRect = %IdleArt
@onready var hint_art: TextureRect = %HintArt
@onready var pickup_fx_art: TextureRect = %PickupFxArt

signal collected(token_id: String, value: int, auto_collected: bool, source_pet_id: String)

var token_id: String = ""
var source_pet_id: String = ""
var value: int = 1
var expires_at: float = 0.0
var already_collected: bool = false
var float_time: float = 0.0
var start_y: float = 0.0
var coin_kind: String = "coin"
var gem_frame_time: float = 0.0

const GEM_IDLE := {
	"pearl": "res://assets/gems/gem_pearl_idle_v1_32x32_2x.png",
	"diamond": "res://assets/gems/gem_diamond_idle_v1_32x32_2x.png",
}
const GEM_PICKUP := {
	"pearl": "res://assets/gems/gem_pearl_pickup_v1_32x32.png",
	"diamond": "res://assets/gems/gem_diamond_pickup_v1_32x32.png",
}


func configure(drop: Dictionary) -> void:
	token_id = str(drop.get("token_id", ""))
	source_pet_id = str(drop.get("source_pet_id", ""))
	value = int(drop.get("value", 1))
	expires_at = float(drop.get("expires_at", 0.0))
	position = Vector2(float(drop.get("x", 0.0)), float(drop.get("y", 0.0))) - Vector2(36.0, 36.0)
	start_y = position.y
	coin_kind = str(drop.get("kind", "coin"))


func _ready() -> void:
	if GEM_IDLE.has(coin_kind):
		var gem_atlas := AtlasTexture.new()
		gem_atlas.atlas = load(GEM_IDLE[coin_kind]) as Texture2D
		gem_atlas.region = Rect2(0, 0, 32, 32)
		idle_art.texture = gem_atlas
		idle_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		idle_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		idle_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		hint_art.visible = false
	DOS_STYLE.style_button(self)
	var transparent_style: StyleBox = StyleBoxEmpty.new()
	for state_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state_name, transparent_style)
	text = ""
	pressed.connect(_on_pressed)
	button_down.connect(_show_hint_art)
	button_up.connect(_show_idle_art)
	mouse_entered.connect(_show_hint_art)
	mouse_exited.connect(_show_idle_art)


func _process(delta: float) -> void:
	if already_collected:
		return
	float_time += delta
	position.y = start_y + sin(float_time * 2.0) * 5.0
	if GEM_IDLE.has(coin_kind) and not already_collected:
		gem_frame_time += delta
		var gem_texture := idle_art.texture as AtlasTexture
		gem_texture.region = Rect2(32.0 if fmod(gem_frame_time, 0.6) >= 0.3 else 0.0, 0.0, 32.0, 32.0)
	if Time.get_unix_time_from_system() >= expires_at:
		collect(true)


func collect(auto_collected: bool = false) -> void:
	if already_collected:
		return
	already_collected = true
	disabled = true
	if GEM_PICKUP.has(coin_kind):
		pickup_fx_art.texture = load(GEM_PICKUP[coin_kind]) as Texture2D
		pickup_fx_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pickup_fx_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pickup_fx_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pickup_fx_art.visible = true
	idle_art.visible = false
	hint_art.visible = false
	collected.emit(token_id, value, auto_collected, source_pet_id)


func animate_to_wallet(target_global_position: Vector2) -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", target_global_position, 0.38)
	tween.tween_property(self, "modulate:a", 0.0, 0.38)
	tween.tween_callback(queue_free).set_delay(0.38)


func discard() -> void:
	queue_free()


func _on_pressed() -> void:
	collect(false)


func _show_hint_art() -> void:
	if already_collected:
		return
	idle_art.visible = false
	hint_art.visible = true


func _show_idle_art() -> void:
	if already_collected:
		return
	idle_art.visible = true
	hint_art.visible = false
