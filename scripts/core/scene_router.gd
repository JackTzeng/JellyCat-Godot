extends Node

const BOOT: String = "res://scenes/boot/boot.tscn"
const TITLE: String = "res://scenes/title/title.tscn"
const EGG_SELECT: String = "res://scenes/egg_select/egg_select.tscn"
const HATCH: String = "res://scenes/hatch/hatch.tscn"
const AQUARIUM: String = "res://scenes/aquarium/aquarium.tscn"

var current_scene_path: String = ""

func go_to(path: String) -> void:
	current_scene_path = path
	RuntimeLogger.log_info("Route to %s" % path.get_file().get_basename().capitalize())
	if SaveManager != null and GameState != null:
		SaveManager.flush_save()
	get_tree().change_scene_to_file(path)


func go_title() -> void:
	go_to(TITLE)


func go_egg_select() -> void:
	go_to(EGG_SELECT)


func go_hatch() -> void:
	go_to(HATCH)


func go_aquarium() -> void:
	go_to(AQUARIUM)


func route_after_boot() -> void:
	if GameState.has_jellycat():
		go_aquarium()
	elif GameState.has_unhatched_egg():
		go_hatch()
	else:
		go_title()
