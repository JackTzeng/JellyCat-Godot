extends Node

const BOOT: String = "res://scenes/boot/boot.tscn"
const TITLE: String = "res://scenes/title/title.tscn"
const EGG_SELECT: String = "res://scenes/egg_select/egg_select.tscn"
const HATCH: String = "res://scenes/hatch/hatch.tscn"
const AQUARIUM: String = "res://scenes/aquarium/aquarium.tscn"
const NURSERY: String = "res://scenes/nursery/nursery.tscn"

var current_scene_path: String = ""
var _pending_scene_path: String = ""
var _route_revision: int = 0

func go_to(path: String) -> void:
	current_scene_path = path
	_pending_scene_path = path
	_route_revision += 1
	var revision: int = _route_revision
	RuntimeLogger.log_info("Route to %s" % path.get_file().get_basename().capitalize())
	if SaveManager != null and GameState != null:
		SaveManager.flush_save()
	call_deferred("_apply_pending_route", revision)


func _apply_pending_route(revision: int) -> void:
	if revision != _route_revision or _pending_scene_path.is_empty():
		return
	var path: String = _pending_scene_path
	_pending_scene_path = ""
	var error: Error = get_tree().change_scene_to_file(path)
	if error != OK:
		RuntimeLogger.log_error("Scene route failed: %s (%s)" % [path, error])


func go_title() -> void:
	go_to(TITLE)


func go_egg_select() -> void:
	go_to(EGG_SELECT)


func go_hatch() -> void:
	go_to(HATCH)


func go_aquarium() -> void:
	go_to(AQUARIUM)


func go_nursery() -> void:
	go_to(NURSERY)


func route_after_boot() -> void:
	if GameState.has_jellycat():
		go_aquarium()
	elif GameState.has_unhatched_egg():
		go_hatch()
	else:
		go_title()
