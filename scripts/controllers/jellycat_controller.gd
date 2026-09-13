extends Node2D

const DEFAULT_SPECIES_ID: String = "normal_jellycat"
const DEFAULT_MAX_STAGE: int = 5
const STAGE_TEXTURE_PATH: String = "res://assets/jellycats/%s/stages/stage_%d.png"

@onready var sprite: Sprite2D = %Sprite

var bob_time: float = 0.0
var current_stage: int = 0
var current_species_id: String = ""

func _ready() -> void:
	set_stage(1)


func _process(delta: float) -> void:
	bob_time += delta
	position.y = sin(bob_time * 2.0) * 8.0
	rotation = sin(bob_time * 1.2) * 0.025


func set_stage(stage: int) -> void:
	var species_id: String = _get_species_id()
	var clamped_stage: int = clamp(stage, 1, _get_max_stage(species_id))
	if clamped_stage == current_stage and species_id == current_species_id:
		return
	var stage_texture: Texture2D = _load_stage_texture(species_id, clamped_stage)
	if stage_texture == null:
		RuntimeLogger.log_error_throttled(
			"missing_jellycat_texture_%s_%d" % [species_id, clamped_stage],
			"Missing JellyCat texture: %s Stage %d" % [species_id, clamped_stage]
		)
		return
	current_stage = clamped_stage
	current_species_id = species_id
	sprite.texture = stage_texture


func _get_species_id() -> String:
	var jellycat: Variant = GameState.get_jellycat()
	if jellycat is Dictionary:
		return str(jellycat.get("species_id", DEFAULT_SPECIES_ID))
	return DEFAULT_SPECIES_ID


func _get_max_stage(species_id: String) -> int:
	var species: Variant = GameApp.get_table("species").get(species_id, {})
	if species is Dictionary:
		return max(int(species.get("max_stage", DEFAULT_MAX_STAGE)), 1)
	return DEFAULT_MAX_STAGE


func _load_stage_texture(species_id: String, stage: int) -> Texture2D:
	var texture_path: String = STAGE_TEXTURE_PATH % [species_id, stage]
	if not ResourceLoader.exists(texture_path):
		texture_path = STAGE_TEXTURE_PATH % [DEFAULT_SPECIES_ID, stage]
	if not ResourceLoader.exists(texture_path):
		return null
	return ResourceLoader.load(texture_path) as Texture2D
