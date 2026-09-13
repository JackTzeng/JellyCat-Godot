extends Node

var version: String = "0.1.0"
var codename: String = "Aquarium Core Prototype"

func load_version() -> void:
	var data: Dictionary = GameApp.load_json_file("res://data/version.json")
	version = str(data.get("version", version))
	codename = str(data.get("codename", codename))


func get_display_text() -> String:
	return "v%s - %s" % [version, codename]
